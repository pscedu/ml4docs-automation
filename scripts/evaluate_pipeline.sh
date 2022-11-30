#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Evaluate campaign predictions against a ground truth. Will generate videos.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --gt_version GT_VERSION
     --in_version EVAL_VERSION
     --iou_thresh IOU_THRESH
     --no_adjust_iou_thresh NO_ADJUST_IOU_THRESH
     --write_comparison_video BOOL

Example:
  $PROGNAME
     --campaign_id 10
     --gt_version f8
     --in_version 1f

Options:
  --campaign_id
      (required) The campaign id.
  --gt_version
      (required) The version suffix of the GROUND TRUTH database.
  --in_version
      (required) The version suffix of the EVALUATED database.
  --iou_thresh
      (optional) Use this threshold to see how much we would capture if this was
                 the last campaign (requires no fixing). Default: 0.5.
  --no_adjust_iou_thresh
      (optional) Use this threshold to see how much we capture in regular 
                 campaigns. Default: 0.8.
  --write_comparison_video
      (optional) Is non-zero, will write a video for "iou_thresh" with detected
                 bounding boxes and ground truth.

EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "gt_version"
    "in_version"
    "iou_thresh"
    "no_adjust_iou_thresh"
    "write_comparison_video"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
iou_thresh=0.5
no_adjust_iou_thresh=0.8
write_comparison_video=0

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
        --gt_version)
            gt_version=$2
            shift 2
            ;;
        --in_version)
            in_version=$2
            shift 2
            ;;
        --iou_thresh)
            iou_thresh=$2
            shift 2
            ;;
        --no_adjust_iou_thresh)
            no_adjust_iou_thresh=$2
            shift 2
            ;;
        --write_comparison_video)
            write_comparison_video=$2
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
if [ -z "$gt_version" ]; then
  echo "Argument 'gt_version' is required."
  exit 1
fi
if [ -z "$in_version" ]; then
  echo "Argument 'in_version' is required."
  exit 1
fi

echo "campaign_id:            ${campaign_id}"
echo "gt_version:             ${gt_version}"
echo "in_version:             ${in_version}"
echo "iou_thresh:             ${iou_thresh}"
echo "no_adjust_iou_thresh:   ${no_adjust_iou_thresh}"
echo "write_comparison_video: ${write_comparison_video}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"


evaluated_db_path=$(get_1800x1200_db_path ${campaign_id} ${in_version})
ls ${evaluated_db_path}

gt_db_path=$(get_1800x1200_db_path ${campaign_id} ${gt_version})
ls ${gt_db_path}
echo "Evaluating on ${gt_db_path}"

for thresh in ${iou_thresh} ${no_adjust_iou_thresh}
do
    metrics_dir="${evaluated_db_path%.*}/tested-on-v${gt_version}-iou${thresh}"
    echo "Will write metrics to ${metrics_dir}"
    mkdir -p ${metrics_dir}

    ${SHUFFLER_DIR}/shuffler.py -i ${evaluated_db_path} \
    filterObjectsSQL \
        --sql 'SELECT objectid FROM objects WHERE name LIKE "%page%"' \| \
    evaluateDetection \
        --gt_db_file ${gt_db_path} \
        --where_object_gt 'name NOT LIKE "%page%"' \
        --evaluation_backend "aggregate-classes" \
        --IoU_thresh ${thresh} \
        --extra_metrics "precision_recall_curve" \
        --out_dir ${metrics_dir}

    if [ "${thresh}" == "${iou_thresh}" ]; then
        echo "^ this is how many did NOT have to be added or removed."
    else
        echo "^ this is how many did NOT have to be added, removed, or ADJUSTED."
    fi

    if ! [ ${write_comparison_video} == "0" ]; then
        ${SHUFFLER_DIR}/shuffler.py \
            -i ${evaluated_db_path} \
            --rootdir ${ROOT_DIR} \
            addDb \
                --db_file ${gt_db_path} \| \
            filterObjectsSQL \
                --sql "SELECT objectid FROM objects WHERE name LIKE '%page%'" \| \
            filterEmptyImages \| \
            writeMedia \
                --image_path "${metrics_dir}.avi" \
                --media video \
                --with_imageid \
                --with_objects \
                --overwrite
    fi
done

echo "Done."
