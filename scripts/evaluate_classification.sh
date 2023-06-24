#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Evaluate detection results against a ground truth. Will generate plots and
output videos.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version IN_VERSION
     --gt_version GT_VERSION
     --model_campaign_id MODEL_CAMPAIGN_ID
     --set_id SET_ID
     --run_id RUN_ID

Example:
  $PROGNAME
     --campaign_id 11
     --in_version 4
     --gt_version 6
     --model_campaign_id 9
     --run_id 0

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version suffix of the CROPPED database.
                 Cropping and inference must have been run on this version.
                 NOTE: Detection evaluation does not require this arg.
  --gt_version
      (required) The version suffix of the GROUND TRUTH database.
  --model_campaign_id
      (required) The campaign of the model.
  --set_id
      (optional) Set id of the model. Default: "set-stamp-1800x1200".
                 This is only for the output naming.
  --run_id
      (optional) Run id of the model. Default: "".
                 This is only for the output naming.
EO
}
    #  --write_comparison_video BOOL

#   --write_comparison_video
#       (optional) If non-zero, will write a video for "iou_thresh" with detected
#                  bounding boxes and ground truth.

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "gt_version"
    "model_campaign_id"
    "set_id"
    "run_id"
)
    # "write_comparison_video"

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
set_id="expand0.5.size260"
# write_comparison_video=0

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
        --gt_version)
            gt_version=$2
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
        # --write_comparison_video)
        #     write_comparison_video=$2
        #     shift 2
        #     ;;
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
if [ -z "$gt_version" ]; then
  echo "Argument 'gt_version' is required."
  exit 1
fi
if [ -z "$model_campaign_id" ]; then
  model_campaign_id=$((campaign_id-1))
  echo "Automatically setting model_campaign_id to ${model_campaign_id}."
fi

echo "campaign_id:            ${campaign_id}"
echo "in_version:             ${in_version}"
echo "gt_version:             ${gt_version}"
echo "model_campaign_id:      ${model_campaign_id}"
echo "set_id:                 ${set_id}"
echo "run_id:                 ${run_id}"
# echo "write_comparison_video: ${write_comparison_video}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh
source ${dir_of_this_file}/../path_generator.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"

evaluated_db_path=$(get_classified_cropped_db_path ${campaign_id} ${in_version} ${model_campaign_id} ${set_id} ${run_id})
ls ${evaluated_db_path}
echo "Ground truth ${gt_db_path}"

gt_db_path="$(get_cropped_db_path ${campaign_id} ${gt_version}.${set_id})"
ls ${gt_db_path}
echo "Evaluating on ${gt_db_path}"


metrics_dir="${evaluated_db_path%.*}/tested-on-v${gt_version}"
echo "Will write metrics to ${metrics_dir}"
mkdir -p ${metrics_dir}

python -m shuffler \
  -i ${evaluated_db_path} \
  evaluateClassification \
    --gt_db_file ${gt_db_path}

echo "Done."
