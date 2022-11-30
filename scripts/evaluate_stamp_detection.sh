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
     --gt_version GT_VERSION
     --model_campaign_id MODEL_CAMPAIGN_ID
     --set_id SET_ID
     --run_id RUN_ID
     --iou_thresh IOU_THRESH
     --no_adjust_iou_thresh NO_ADJUST_IOU_THRESH
     --write_comparison_video BOOL

Example:
  $PROGNAME
     --campaign_id 10
     --gt_version f8
     --model_campaign_id 9
     --run_id 0

Options:
  --campaign_id
      (required) The campaign id.
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
    "model_campaign_id"
    "set_id"
    "run_id"
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
set_id="set-stamp-1800x1200"
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
if [ -z "$model_campaign_id" ]; then
  model_campaign_id=$((campaign_id-1))
  echo "Automatically setting model_campaign_id to ${model_campaign_id}."
fi

echo "campaign_id:            ${campaign_id}"
echo "gt_version:             ${gt_version}"
echo "model_campaign_id:      ${model_campaign_id}"
echo "set_id:                 ${set_id}"
echo "run_id:                 ${run_id}"
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

echo "================================================="
echo "         Stamps both inside and outside pages."
echo "================================================="

evaluated_db_path=$(get_detected_db_path ${campaign_id} ${model_campaign_id} ${set_id} ${run_id})
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
        --evaluation_backend "class-agnostic" \
        --extra_metrics "precision_recall_curve" \
        --IoU_thresh ${thresh} \
        --out_dir ${metrics_dir}
    
    if [ "${thresh}" == "${iou_thresh}" ]; then
        echo "^ this is how many did NOT have to be added or removed."
    else
        echo "^ this is how many did NOT have to be added, removeed, or ADJUSTED."
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

echo "================================================="
echo "         Now stamps inside pages only."
echo "================================================="

# Only keep stamps inside good (not back) pages in the evaluated version.
filtered_gt_db_path=$(get_1800x1200_db_path ${campaign_id} ${gt_version}.inside_good_pages)
${SHUFFLER_DIR}/shuffler.py \
    -i ${gt_db_path} \
    -o ${filtered_gt_db_path} \
    filterObjectsInsideCertainObjects \
        --where_shadowing_objects "name IN ('page_rb', 'page_lb', 'pagerb', 'pagelb')" \| \
    filterObjectsInsideCertainObjects \
        --invert \
        --where_shadowing_objects "name LIKE '%page%'"

# Add GT pages to the evaluated db.
gt_pages_db_path=$(get_1800x1200_db_path ${campaign_id} ${gt_version}.pages)
${SHUFFLER_DIR}/shuffler.py \
    -i ${gt_db_path} \
    -o ${gt_pages_db_path} \
    filterObjectsSQL --sql "SELECT objectid FROM objects WHERE name NOT LIKE '%page%'"

# Only keep stamps inside good (not back) pages in the evaluated version.
filtered_evaluated_db_path=$(get_detected_db_path ${campaign_id} ${model_campaign_id} ${set_id} ${run_id}.inside_good_pages)
${SHUFFLER_DIR}/shuffler.py \
    -i ${evaluated_db_path} \
    -o ${filtered_evaluated_db_path} \
    filterObjectsSQL \
        --sql "SELECT objectid FROM objects WHERE name LIKE '%page%'" \| \
    addDb \
        --db_file ${gt_pages_db_path} \| \
    filterObjectsInsideCertainObjects \
        --where_shadowing_objects "name IN ('page_rb', 'page_lb', 'pagerb', 'pagelb')" \| \
    filterObjectsInsideCertainObjects \
        --invert \
        --where_shadowing_objects "name LIKE '%page%'" \| \
    filterObjectsSQL \
        --sql "SELECT objectid FROM objects WHERE name LIKE '%page%'"

for thresh in ${iou_thresh} ${no_adjust_iou_thresh}
do

    metrics_dir="${evaluated_db_path%.*}/tested-on-v${gt_version}-inside-pages-iou${thresh}"
    echo "Will write metrics to ${metrics_dir}"
    mkdir -p ${metrics_dir}

    echo "Evaluating on: ${filtered_gt_db_path}"
    # NOTE: pages were removed when making filtered_evaluated_db_path.
    ${SHUFFLER_DIR}/shuffler.py -i ${filtered_evaluated_db_path} \
    evaluateDetection \
        --gt_db_file ${filtered_gt_db_path} \
        --where_object_gt 'name NOT LIKE "%page%"' \
        --evaluation_backend "class-agnostic" \
        --extra_metrics "precision_recall_curve" \
        --IoU_thresh ${thresh} \
        --out_dir ${metrics_dir}

    if [ "${thresh}" == "${iou_thresh}" ]; then
        echo "^ this is how many did NOT have to be added or removed."
    else
        echo "^ this is how many did NOT have to be added, removed, or ADJUSTED."
    fi

    if ! [ ${write_comparison_video} == "0" ]; then
        ${SHUFFLER_DIR}/shuffler.py \
            -i ${filtered_evaluated_db_path} \
            --rootdir ${ROOT_DIR} \
            addDb \
                --db_file ${filtered_gt_db_path} \| \
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
