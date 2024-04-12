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
     --num_images_for_video NUMBER

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
      (optional) Threshold for consindering a successful detection.
  --write_comparison_video
      (optional) Is non-zero, will write a video for "iou_thresh" with detected
                 bounding boxes and ground truth.
  --num_images_for_video
      (optional) How many random images to write to the video.

EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "gt_version"
    "in_version"
    "iou_thresh"
    "write_comparison_video"
    "num_images_for_video"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
iou_thresh=0.8
write_comparison_video=0
num_images_for_video=100

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
        --write_comparison_video)
            write_comparison_video=$2
            shift 2
            ;;
        --num_images_for_video)
            num_images_for_video=$2
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
echo "write_comparison_video: ${write_comparison_video}"
echo "num_images_for_video:   ${num_images_for_video}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh
source ${dir_of_this_file}/../path_generator.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"


evaluated_db_path=$(get_1800x1200_db_path ${campaign_id} ${in_version})
ls ${evaluated_db_path}

gt_db_path=$(get_1800x1200_db_path ${campaign_id} ${gt_version})
ls ${gt_db_path}
echo "Evaluating on ${gt_db_path}"

metrics_dir="${evaluated_db_path%.*}/tested-on-v${gt_version}-iou${iou_thresh}"
echo "Will write metrics to ${metrics_dir}"
mkdir -p ${metrics_dir}

echo "Evaluating in and out of good pages."
python -m shuffler -i ${evaluated_db_path} \
    filterObjectsSQL \
        --delete \
        --sql 'SELECT objectid FROM objects WHERE name LIKE "%page%"' \| \
    evaluateDetection \
        --gt_db_file ${gt_db_path} \
        --where_object_gt 'name NOT LIKE "%page%"' \
        --evaluation_backend "aggregate-classes" \
        --IoU_thresh ${iou_thresh} \
        --extra_metrics "precision_recall_curve" \
        --out_dir ${metrics_dir}
echo "This is how much the accuracy is IN and OUT of pages."


echo "================================================="
echo "         Now stamps inside pages only."
echo "================================================="

echo "Only keep stamps inside good (not back) pages in the evaluated version."
filtered_gt_db_path=$(get_1800x1200_db_path ${campaign_id} ${gt_version}.inside_good_pages)
python -m shuffler \
    -i ${gt_db_path} \
    -o ${filtered_gt_db_path} \
    filterObjectsInsideCertainObjects \
        --keep \
        --where_shadowing_objects "name IN ('page', 'page_r', 'page_l', 'pager', 'pagel')" \| \
    filterObjectsSQL \
        --delete \
        --sql "SELECT objectid FROM objects WHERE name LIKE '%page%'"

echo "Add GT pages to the evaluated db."
gt_pages_db_path=$(get_1800x1200_db_path ${campaign_id} ${gt_version}.front_pages)
python -m shuffler \
    -i ${gt_db_path} \
    -o ${gt_pages_db_path} \
    filterObjectsSQL \
        --keep \
        --sql "SELECT objectid FROM objects WHERE name IN ('page', 'page_r', 'page_l', 'pager', 'pagel')"

echo "Only keep stamps inside good (not back) pages in the evaluated version."
filtered_evaluated_db_path=$(get_1800x1200_db_path ${campaign_id} ${in_version}.front_pages)
python -m shuffler \
    -i ${evaluated_db_path} \
    -o ${filtered_evaluated_db_path} \
    filterObjectsSQL \
        --delete \
        --sql "SELECT objectid FROM objects WHERE name LIKE '%page%'" \| \
    addDb \
        --db_file ${gt_pages_db_path} \| \
    filterObjectsInsideCertainObjects \
        --keep \
        --where_shadowing_objects "name LIKE '%page%'" \| \
    filterObjectsSQL \
        --delete \
        --sql "SELECT objectid FROM objects WHERE name LIKE '%page%'"

echo "Evaluating inside good pages."
python -m shuffler \
    -i ${filtered_evaluated_db_path} \
    evaluateDetection \
        --gt_db_file ${filtered_gt_db_path} \
        --evaluation_backend "aggregate-classes" \
        --extra_metrics "precision_recall_curve" \
        --IoU_thresh ${iou_thresh} \
        --out_dir ${metrics_dir}



if ! [ ${write_comparison_video} == "0" ]; then
    echo "Writing comparison video."
    python -m shuffler \
        -i ${evaluated_db_path} \
        --rootdir ${ROOT_DIR} \
        addDb \
            --db_file ${gt_db_path} \| \
        filterObjectsSQL \
            --delete \
            --sql "SELECT objectid FROM objects WHERE name LIKE '%page%'" \| \
        filterImagesWithoutObjects \| \
        randomNImages -n ${num_images_for_video} \| \
        writeMedia \
            --image_path "${metrics_dir}.avi" \
            --media video \
            --with_imageid \
            --with_objects \
            --overwrite
fi

echo "Done."
