#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
This script starts batch jobs that train a classification model based on
specified data splits and the config file.

Usage:
  $PROGNAME
    --splits_dir SPLITS_DIR
    --campaign_id CAMPAIGN_ID
    --set_id SET_ID
    --run_id RUN_ID
    --experiments_path EXPERIMENTS_PATH
    --dry_run DRY_RUN

Example:
  $PROGNAME
    --splits_dir ${PROJECT_DIR}/shared/databases/campaign7/crops/splits/campaign3to7-6Kx4K.v7.expand20.size260.cropped
    --campaign_id 6
    --set_id="stamp-1800x1200"
    --run_id 0

Options:
  --splits_dir
      (required) Directory with data splits, e.g. split0, split1.
      Inside each of these dirs, there must be files "train.db", "validation.db".
      File at ${experiments_path} specifies which data splits to use.
  --campaign_id
      (required) Id of campaign. Example: "6"
  --set_id
      (required) Id of set. Example: 3.
  --run_id
      (required) Id of run. Example: 0.
  --experiments_path
      (optional) Path to "experiments.txt" file, which is made according to experiments.example.txt.
      Default: ${CLASSIFICATION_DIR}/campaign${campaign_id}/${set_id}/run${run_id}/experiments.txt.
      Specify for debugging of experimenting. 
  --dry_run
      (optional) Enter 1 to NOT submit jobs. Default: "0"
  -h|--help
      Print usage and exit.
EO
}

ARGUMENT_LIST=(
    "splits_dir"
    "campaign_id"
    "set_id"
    "run_id"
    "experiments_path"
    "dry_run"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
dry_run=0

eval set --$opts

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --splits_dir)
            splits_dir=$2
            shift 2
            ;;
        --campaign_id)
            campaign_id=$2
            shift 2
            ;;
        --set_id)
            set_id=$2
            shift 2
            ;;
        --run_id)
            run_id=$2
            shift 2
            ;;
        --experiments_path)
            experiments_path=$2
            shift 2
            ;;
        --dry_run)
            dry_run=$2
            shift 2
            ;;
        --) # No more arguments
            shift
            break
            ;;
        *)
            echo "Arg '$1' is not supported."
            exit 1
            ;;
    esac
done

# Check required arguments.
if [ -z "$splits_dir" ]; then
  echo "Argument 'splits_dir' is required."
  exit 1
fi
if [ -z "$campaign_id" ]; then
  echo "Argument 'campaign_id' is required."
  exit 1
fi
if [ -z "$set_id" ]; then
  echo "Argument 'set' is required."
  exit 1
fi
if [ -z "$run_id" ]; then
  echo "Argument 'run' is required."
  exit 1
fi

# The end of the parsing code.
################################################################################

# Import all constants. Assumes this file is in scripst/train_classification.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"

# Will contain hyperparameter folders.
run_dir=$(get_classification_run_dir ${campaign_id} ${set_id} ${run_id})
# Get the default experiments_path, if not provided.
if [ -z "$experiments_path" ]; then
  experiments_path=$(get_classification_experiments_path ${campaign_id} ${set_id} ${run_id})
fi

shuffler_bin=${SHUFFLER_DIR}/shuffler.py

template_path="${dir_of_this_file}/template.sbatch"
if [ ! -f "${template_path}" ]; then
    echo "Job template does not exist at '${template_path}'"
    exit 1
fi
if [ ! -d "$splits_dir" ]; then
    echo "Directory with splits does not exist at '$splits_dir'"
    exit 1
fi

echo "run_dir:          ${run_dir}"
echo "experiments_path: ${experiments_path}"
echo "splits_dir:       ${splits_dir}"
echo "campaign_id:      ${campaign_id}"
echo "set_id:           ${set_id}"
echo "run_id:           ${run_id}"
echo "dry_run:          ${dry_run_submit}"

for line in $(cat ${experiments_path})
do
    IFS=';' # Delimiter
    read -ra ADDR <<< "$line" # line is read into an array as tokens separated by IFS
    echo "Line: ${ADDR[@]}"
    if [[ ${ADDR[0]} == "#" ]]; then
        echo "This line is a comment. Skip."
        continue
    fi

    HYPER_N="${ADDR[0]}"
    SPLIT="${ADDR[1]}"
    CONFIG_SUFFIX="${ADDR[2]}"
    SAVE_SNAPSHOTS="${ADDR[3]}"

    split_dir=$splits_dir/$SPLIT
    if [ ! -d "$split_dir" ]; then
        echo "Directory with a split does not exist at '$split_dir'"
        exit 1
    fi

    hyper_dir="${run_dir}/hyper${HYPER_N}"
    mkdir -p ${hyper_dir}

    train_db_file="${split_dir}/train.db"
    val_db_file="${split_dir}/validation.db"
    ls ${train_db_file}
    ls ${val_db_file}

    # Stem of the batch job (without extension).
    batch_job_dir="${hyper_dir}/batch_job"
    mkdir -p "${batch_job_dir}"
    batch_job_path_stem="${batch_job_dir}/train_classification"

    # Make an encoding from stamp names to numbers.
    # Creates property key,value = "name_id","<id>" for all except LIKE '%??%'.
    encoding_file="${hyper_dir}/encoding.json"
    ${shuffler_bin} -i ${train_db_file} -o ${train_db_file} \
      filterObjectsSQL \
        --sql "SELECT objectid FROM objects WHERE name LIKE '%??%' OR name LIKE '%page%';" \| \
      encodeNames --out_encoding_json_file ${encoding_file}
    # Use the existing encoding file to assign name_ids to validation file.
    ${shuffler_bin} -i ${val_db_file} -o ${val_db_file} \
      filterObjectsSQL \
        --sql "SELECT objectid FROM objects WHERE name LIKE '%page%';" \| \
      encodeNames --in_encoding_json_file ${encoding_file}

    # Info about the config is written in the file, so that the inference can use it.
    config_suffix_file="${hyper_dir}/config_suffix.txt"
    echo ${CONFIG_SUFFIX} > ${config_suffix_file}

    wandb_basename=$(basename -- "${splits_dir}")_${SPLIT}

    sed \
        -e "s|TRAIN_DB_FILE|${train_db_file}|g" \
        -e "s|VAL_DB_FILE|${val_db_file}|g" \
        -e "s|ROOT_DIR|${ROOT_DIR}|g" \
        -e "s|SHUFFLER_DIR|${SHUFFLER_DIR}|g" \
        -e "s|CONFIG_SUFFIX|${CONFIG_SUFFIX}|g" \
        -e "s|OUTPUT_DIR|${hyper_dir}|g" \
        -e "s|OLTR_DIR|${OLTR_DIR}|g" \
        -e "s|WANDB_BASENAME|${wandb_basename}|g" \
        -e "s|ENCODING_FILE|${encoding_file}|g" \
        -e "s|CONDA_INIT_SCRIPT|${CONDA_INIT_SCRIPT}|g" \
        -e "s|CONDA_OLTR_ENV|${CONDA_OLTR_ENV}|g" \
        ${template_path} > "${batch_job_path_stem}.sbatch"
    status=$?
    if [ ${status} -ne 0 ]; then
        echo "Failed to use the template from '${template_path}'"
        exit ${status}
    fi

    echo "Wrote a job file to '${batch_job_path_stem}.sbatch'."
    if [ ${dry_run} == "0" ]; then
        JID=$(sbatch -A ${ACCOUNT} \
            --output="${batch_job_path_stem}.out" \
            --error="${batch_job_path_stem}.err" \
            "${batch_job_path_stem}.sbatch")
        echo $JID
        JOB_ID=${JID##* }
        touch "${batch_job_dir}/job_ids.txt"
        echo `date`" "${JOB_ID} >> "${batch_job_dir}/job_ids.txt"
    fi

    IFS=' ' # reset to default value after usage
done
