#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Examine trained page-detection results, and pick the best model.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --run_id RUN_ID

Example:
  $PROGNAME
     --campaign_id 7

Options:
  --campaign_id
      (required) The campaign id.
  --run_id
      (optional) The try id. Use if the 0th try failed. Default is 0.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "run_id"
    "clean_up"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
run_id=0

eval set --$opts

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --campaign_id)
            campaign_id=$2
            shift 2
            ;;
        --run_id)
            run_id=$2
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
if [ -z "$campaign_id" ]; then
  echo "Argument 'campaign_id' is required."
  exit 1
fi

echo "campaign_id:            ${campaign_id}"
echo "run_id:                 ${run_id}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"

set_id="set-page-1800x1200"

# Will be used to name dirs and databases.
experiments_path=$(get_detection_experiments_path ${campaign_id} ${set_id} ${run_id})
echo "experiments_path: ${experiments_path}"


# Analyze the results and get "best_hyper_id" and "best_epoch_id".
python3 ${dir_of_this_file}/../scripts/detection_training_polygon_yolov5_jobs/postprocess.py \
  --detection_root_dir ${DETECTION_DIR} \
  --experiments_path "${experiments_path}" \
  --campaign ${campaign_id} \
  --set_id ${set_id} \
  --run_id ${run_id} \
  --ignore_splits "full" \
  --copy_best_model_from_split "full"

echo "Done."
