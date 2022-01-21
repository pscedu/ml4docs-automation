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
     --in_version IN_VERSION
     --run_id RUN_ID
     --clean_up clean_up

Example:
  $PROGNAME
     --campaign_id 7
     --in_version 7

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version suffix of the output database.
  --run_id
      (optional) The try id. Use if the 0th try failed. Default is 0.
  --clean_up
      (optional) If not 0, will skip cleaning up space by deleteing non-best model snapshots.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
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
clean_up=0

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
        --in_version)
            in_version=$2
            shift 2
            ;;
        --run_id)
            run_id=$2
            shift 2
            ;;
        --clean_up)
            clean_up=$2
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
if [ -z "$in_version" ]; then
  echo "Argument 'in_version' is required."
  exit 1
fi

echo "campaign_id:            ${campaign_id}"
echo "in_version:             ${in_version}"
echo "run_id:                 ${run_id}"
echo "clean_up:               ${clean_up}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_ENV_DIR}/shuffler
echo "Conda environment is activated: '${CONDA_ENV_DIR}/shuffler'"

# Will be used to name dirs and databases.
stem="campaign3to${campaign_id}-1800x1200.v${in_version}.page"
coco_dir="${DETECTION_DIR}/campaign${campaign_id}/splits/${stem}"
run_dir="${DETECTION_DIR}/campaign${campaign_id}/set-page-1800x1200/run${run_id}"
echo "coco_dir: ${coco_dir}"
echo "run_dir: ${run_dir}"

# Analyze the results and get "best_hyper_id" and "best_epoch_id".
python3 ${dir_of_this_file}/../scripts/detection_training_retinanet_jobs/postprocess.py \
  --experiments_path "${coco_dir}/experiments-run${run_id}.txt" \
  --campaign ${campaign_id} \
  --set="-page-1800x1200" \
  --run ${run_id} \
  --ignore_splits "full" \
  --copy_best_model_from_split "full" \
  --clean_up ${clean_up}

echo "Done."
