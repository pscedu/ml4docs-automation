#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
This scripts performs the inference with a trained detection model.
It allows to run a model trained on any campaign/set/run on any database.

Usage:
  $PROGNAME
     --in_db_file IN_DB_FILE
     --out_db_file OUT_DB_FILE
     --model_campaign_id CAMPAIGN_ID
     --class_name CLASS_NAME
     --set_id SET_ID
     --run_id RUN_ID
     --gpu_type GPU_TYPE
     --dry_run DRY_RUN

Example:
  $PROGNAME
     --in_db_file "/ocean/projects/hum180001p/shared/databases/campaign8/campaign8-1800x1200.v1.db"
     --out_db_file "/ocean/projects/hum180001p/shared/databases/campaign8/campaign8-1800x1200.v2.db"
     --model_campaign_id 7
     --class_name "stamp"
     --set_id "set-stamp-1800x1200"

Options:
  --in_db_file
      (required) Full path to the input database file.
                 Asking for the full path to allow inter-campaign inference.
  --out_db_file
      (required) Full path to the output database file.
                 Asking for the path to allow inter-campaign inference.
  --model_campaign_id
      (required) Id of campaign OF THE MODEL. Example: 7.
  --class_name
      (required) "stamp" or "page". Detected objects will have this name.
  --set_id
      (required) Id of set. Example: set-stamp-1800x1200.
  --run_id
      (optional) Id of run. Example: 0. If not given, use the best run.
  --gpu_type
      (optional) GPU type to use. Default: "v100-32".
  --dry_run
      (optional) Enter 1 to NOT submit the job. Default: 0.
  -h|--help
      Print usage and exit.
EO
}

ARGUMENT_LIST=(
    "in_db_file"
    "out_db_file"
    "model_campaign_id"
    "class_name"
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
        --class_name)
            class_name=$2
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
if [ -z "$class_name" ]; then
  echo "Argument 'class_name' is required."
  exit 1
fi
if [ -z "$set_id" ]; then
  echo "Argument 'set_id' is required."
  exit 1
fi

echo "in_db_file:       $in_db_file"
echo "out_db_file:      $out_db_file"
echo "model_campaign_id: $model_campaign_id"
echo "class_name:       $class_name"
echo "set_id:           $set_id"
echo "run_id:           $run_id"
echo "gpu_type:         $gpu_type"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../../constants.sh

template_path="${dir_of_this_file}/template.sbatch"
if [ ! -f "$template_path" ]; then
    echo "Job template does not exist at '$template_path'"
    exit 1
fi

model_dir="${DETECTION_DIR}/campaign${model_campaign_id}/${set_id}"
ls ${model_dir}

if [ -z "$run_id" ]; then
  model_path="${model_dir}/snapshots_best_full.pt"
else
  echo "Argument 'run_id' is set to ${run_id}."
  model_path=$(ls -1 ${model_dir}/*${run_id}*.pt | tail -n 1)
fi

batch_jobs_dir="${DATABASES_DIR}/campaign${model_campaign_id}/batch_jobs"
mkdir -p ${batch_jobs_dir}
batch_job_path_stem="${batch_jobs_dir}/detection_inference_${set_id}_${run_id}"

sed \
    -e "s|IN_DB_FILE|${in_db_file}|g" \
    -e "s|OUT_DB_FILE|${out_db_file}|g" \
    -e "s|MODEL_PATH|${model_path}|g" \
    -e "s|CLASS_NAME|${class_name}|g" \
    -e "s|ROOT_DIR|${ROOT_DIR}|g" \
    -e "s|SHUFFLER_DIR|${SHUFFLER_DIR}|g" \
    -e "s|YOLOV5_DIR|${YOLOV5_DIR}|g" \
    -e "s|GPU_TYPE|${gpu_type}|g" \
    -e "s|CONDA_INIT_SCRIPT|${CONDA_INIT_SCRIPT}|g" \
    -e "s|CONDA_YOLOV5_ENV|${CONDA_YOLOV5_ENV}|g" \
    ${template_path} > "${batch_job_path_stem}.sbatch"
status=$?
if [ ${status} -ne 0 ]; then
    echo "Failed to use the template from '${template_path}'"
    exit ${status}
fi

echo "Wrote a job file to '${batch_job_path_stem}.sbatch' without submitting it."
if [ ${dry_run} == "0" ]; then
    sbatch -A ${ACCOUNT} \
        --output="${batch_job_path_stem}.out" \
        --error="${batch_job_path_stem}.err" \
        "${batch_job_path_stem}.sbatch"
else
    echo "Wrote a job file without submitting it."
fi
