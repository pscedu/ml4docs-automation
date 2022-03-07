#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Examine trained stamp-classification results, and pick the best model.
This is a thin wrapper around scripts/classification_training/postprocess.py

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --set_id SET_ID
     --run_id RUN_ID

Example:
  $PROGNAME
     --campaign_id 7

Options:
  --campaign_id
      (required) The campaign id.
  --set_id
      (optional) The id of cropped database. Use if want non-standard data.
                 Default: "expand50.size260". Look up options in dir "crops".
  --run_id
      (optional) The try id. Use if the 0th try failed. Default is 0. 
                 We don't care about in_version, but care about run_id.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "set_id"
    "run_id"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
set_id="expand0.5-size260"
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
        --set_id)
            set_id=$2
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
echo "set_id:                 ${set_id}"
echo "run_id:                 ${run_id}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

# Analyze the results and get "best_hyper_id" and "best_epoch_id".
python3 ${dir_of_this_file}/../scripts/classification_training/postprocess.py \
  --experiments_path $(get_classification_experiments_path ${campaign_id} ${set_id} ${run_id}) \
  --classification_dir ${CLASSIFICATION_DIR} \
  --campaign_id ${campaign_id} \
  --set_id ${set_id} \
  --run_id ${run_id} \
  --ignore_splits "full" \
  --copy_best_model_from_split "full"

echo "Done."
