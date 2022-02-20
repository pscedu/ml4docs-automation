#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
This script starts a batch job that trains a classification model.

Usage:
  $PROGNAME
    --experiments_path EXPERIMENTS_PATH
    --splits_dir SPLITS_DIR
    --campaign_id CAMPAIGN_ID
    --in_version IN_VERSION
    --set_id SET_ID
    --run_id RUN_ID

Example:
  $PROGNAME
    --experiments_path /ocean/projects/hum180001p/shared/databases/campaign7/crops/campaign5/set0/run0/experiment.txt
    --splits_dir /ocean/projects/hum180001p/shared/databases/campaign7/crops/splits/campaign3to5-1800x1200.v2
    --campaign_id 6
    --in_version 7
    --set_id="set-stamp-1800x1200"
    --run_id 0

Options:
  --experiments_path
      (required) Path to "experiments.txt" file, which is made according to experiments.example.txt.
  --splits_dir
      (required) Directory with data splits.
  --campaign_id
      (required) Id of campaign. Example: "6"
  --in_version
      (required) The version suffix of the input database.
  --set_id
      (required) Id of set. Example: 3.
  --run_id
      (required) Id of run. Example: 0.
  --dry_run
      (optional) Enter 1 to NOT submit jobs. Default: "0"
  -h|--help
      Print usage and exit.
EO
}

ARGUMENT_LIST=(
    "experiments_path"
    "splits_dir"
    "campaign_id"
    "in_version"
    "set_id"
    "run_id"
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
        --experiments_path)
            experiments_path=$2
            shift 2
            ;;
        --splits_dir)
            splits_dir=$2
            shift 2
            ;;
        --campaign_id)
            campaign_id=$2
            shift 2
            ;;
        --in_version)
            in_version=$2
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
if [ -z "$experiments_path" ]; then
  echo "Argument 'experiments_path' is required."
  exit 1
fi
if [ -z "$splits_dir" ]; then
  echo "Argument 'splits_dir' is required."
  exit 1
fi
if [ -z "$campaign_id" ]; then
  echo "Argument 'campaign_id' is required."
  exit 1
fi
if [ -z "$in_version" ]; then
  echo "Argument 'in_version' is required."
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
conda activate ${CONDA_ENV_DIR}/shuffler
echo "Conda environment is activated: '${CONDA_ENV_DIR}/shuffler'"

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

# Will contain hyperparameter folders.
results_dir="${CLASSIFICATION_DIR}/campaign${campaign_id}/${set_id}/run${run_id}"

echo "experiments_path: ${experiments_path}"
echo "splits_dir:       $splits_dir"
echo "campaign_id:      ${campaign_id}"
echo "in_version:       ${in_version}"
echo "set_id:           $set_id"
echo "run_id:           $run_id"
echo "results_dir:      $results_dir"
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

    experiment_result_dir="${results_dir}/hyper${HYPER_N}"
    mkdir -p ${experiment_result_dir}

    train_db_file="${split_dir}/train.db"
    val_db_file="${split_dir}/validation.db"
    ls ${train_db_file}
    ls ${val_db_file}

    # Stem of the batch job (without extension).
    batch_job_dir="${experiment_result_dir}/batch_job"
    mkdir -p "${batch_job_dir}"
    batch_job_path_stem="${batch_job_dir}/train_classification"

    # Make an encoding from stamp names to numbers.
    # Creates property key,value = "name_id","<id>" for all except LIKE '%??%'.
    encoding_file="${experiment_result_dir}/encoding.json"
    ${shuffler_bin} -i ${train_db_file} -o ${train_db_file} \
      filterObjectsSQL \
        --sql "SELECT objectid FROM objects WHERE name LIKE '%??%' OR name LIKE '%page%';" \| \
      encodeNames --encoding_json_file ${encoding_file}

    # Info about the config is written in the file, so that the inference can use it.
    config_suffix_file="${experiment_result_dir}/config_suffix.txt"
    echo ${CONFIG_SUFFIX} > ${config_suffix_file}

    sed \
        -e "s|TRAIN_DB_FILE|${train_db_file}|g" \
        -e "s|VAL_DB_FILE|${val_db_file}|g" \
        -e "s|ROOT_DIR|${ROOT_DIR}|g" \
        -e "s|SHUFFLER_DIR|${SHUFFLER_DIR}|g" \
        -e "s|CONFIG_SUFFIX|${CONFIG_SUFFIX}|g" \
        -e "s|OUTPUT_DIR|${experiment_result_dir}|g" \
        -e "s|OLTR_DIR|${OLTR_DIR}|g" \
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
