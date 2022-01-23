#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
This script starts a batch job that does classification inference.

Usage:
  $PROGNAME
     --in_db_file IN_DB_FILE
     --out_db_file OUT_DB_FILE
     --model_campaign_id CAMPAIGN_ID
     --set_id SET_ID
     --run_id RUN_ID
     --gpu_type GPU_TYPE
     --dry_run DRY_RUN

Example:
  $PROGNAME
    --in_db_file /ocean/projects/hum180001p/shared/databases/campaign8/crops/campaign8-6Kx4K.v3.filtered.expanded.cropped.db
    --out_db_file /ocean/projects/hum     --model_campaign_id 7
     --set_id "set-expand50"

Options:
  --in_db_file
      (required) Full path to the input database file.
                 Asking for the full path to allow inter-campaign inference.
  --out_db_file
      (required) Full path to the output database file.
                 Asking for the path to allow inter-campaign inference.
  --model_campaign_id
      (required) Id of campaign OF THE MODEL. Example: 7.
  --set_id
      (required) Id of set. Example: set-stamp-1800x1200.
  --run_id
      (optional) Id of run. Example: 0. If not given, use the best run.
  --gpu_type
      (optional) GPU type to use. Default: "v100-32".
  --dry_run
      (optional) Enter 1 to NOT submit jobs. Default: "0"
  -h|--help
      Print usage and exit.
EO
}

ARGUMENT_LIST=(
    "in_db_file"
    "out_db_file"
    "model_campaign_id"
    "set_id"
    "run_id"
    "gpu_type"
    "dry_run"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
gpu_type="v100-32"
run_id="best"
dry_run=0

eval set --$opts

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --in_db_file)
            in_db_file=$2
            shift 2
            ;;
        --out_db_file)
            out_db_file=$2
            shift 2
            ;;
        --model_campaign_id)
            model_campaign_id=$2
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
        --gpu_type)
            gpu_type=$2
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
if [ -z "$in_db_file" ]; then
  echo "Argument 'in_db_file' is required."
  exit 1
fi
if [ -z "$out_db_file" ]; then
  echo "Argument 'out_db_file' is required."
  exit 1
fi
if [ -z "$model_campaign_id" ]; then
  echo "Argument 'model_campaign_id' is required."
  exit 1
fi
if [ -z "$set_id" ]; then
  echo "Argument 'set_id' is required."
  exit 1
fi

echo "in_db_file:       $in_db_file"
echo "out_db_file:      $out_db_file"
echo "model_campaign_id: $model_campaign_id"
echo "set_id:           $set_id"
echo "run_id:           $run_id"
echo "gpu_type:         $gpu_type"

# The end of the parsing code.
################################################################################

# Import all constants. Assumes this file is in scripst/inference_classification.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../../constants.sh

template_path="${dir_of_this_file}/template.sbatch"
if [ ! -f "${template_path}" ]; then
    echo "Job template does not exist at '${template_path}'"
    exit 1
fi

model_dir="${CLASSIFICATION_DIR}/campaign${model_campaign_id}/${set_id}"
ls ${model_dir}

if [ -z "$run_id" ]; then
else
  echo "Argument 'run_id' is set to ${run_id}."
  model_dir="${model_dir}/run${run_id}"
fi
echo "Expect to find the model in ${model_dir}"

# Stem of the batch job (without extension).
batch_jobs_dir="${model_dir}/batch_jobs"
mkdir -p "${batch_jobs_dir}"
batch_job_path_stem="${batch_jobs_dir}/classification_inference"

sed \
    -e "s|IN_DB_FILE|${in_db_file}|g" \
    -e "s|OUT_DB_FILE|${out_db_file}|g" \
    -e "s|ROOT_DIR|${ROOT_DIR}|g" \
    -e "s|MODEL_DIR|${model_dir}|g" \
    -e "s|SHUFFLER_DIR|${SHUFFLER_DIR}|g" \
    -e "s|OLTR_DIR|${OLTR_DIR}|g" \
    -e "s|GPU_TYPE|${gpu_type}|g" \
    -e "s|CONDA_INIT_SCRIPT|${CONDA_INIT_SCRIPT}|g" \
    -e "s|CONDA_OLTR_ENV|${CONDA_OLTR_ENV}|g" \
    ${template_path} > "${batch_job_path_stem}.sbatch"
status=$?
if [ ${status} -ne 0 ]; then
    echo "Failed to use the template from '${template_path}'"
    exit ${status}
fi

echo "Wrote a job file to '${batch_job_path_stem}.sbatch' without submitting it."
if [ ${dry_run} == "0" ]; then
    JID=$(sbatch -A ${ACCOUNT} \
        --output="${batch_job_path_stem}.out" \
        --error="${batch_job_path_stem}.err" \
        "${batch_job_path_stem}.sbatch")

    echo $JID
    JOB_ID=${JID##* }
    touch "${batch_jobs_dir}/job_ids.txt"
    echo `date`" "${JOB_ID} >> "${batch_jobs_dir}/job_ids.txt"
fi

IFS=' ' # reset to default value after usage

