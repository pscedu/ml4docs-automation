#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Start page-detection model training.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version IN_VERSION
     --k_fold K_FOLD
     --run_id RUN_ID
     --dry_run_export DRY_RUN_EXPORT
     --dry_run_submit DRY_RUN_SUBMIT

Example:
  $PROGNAME
     --campaign_id 7
     --in_version 7

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version suffix of the output database.
  --k_fold
      (optional) Will perform k-fold validation. Default is 5.
  --run_id
      (optional) The try id. Use if the 0th try failed. Default is 0.
  --dry_run_export
      (optional) Enter 1 when the data was already exported to COCO. Default: "0"
  --dry_run_submit
      (optional) Enter 1 to NOT submit jobs. Default: "0"
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "k_fold"
    "run_id"
    "dry_run_export"
    "dry_run_submit"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
k_fold=5
run_id=0
dry_run_export=0
dry_run_submit=0

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
        --k_fold)
            k_fold=$2
            shift 2
            ;;
        --run_id)
            run_id=$2
            shift 2
            ;;
        --dry_run_export)
            dry_run_export=$2
            shift 2
            ;;
        --dry_run_submit)
            dry_run_submit=$2
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
echo "k_fold:                 ${k_fold}"
echo "run_id:                 ${run_id}"
echo "dry_run_export:         ${dry_run_export}"
echo "dry_run_submit:         ${dry_run_submit}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh
source ${dir_of_this_file}/../path_generator.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"

# Will be used to name dirs and databases.
splits_dir="$(get_page_detection_splits_uptonow_dir $campaign_id $in_version)"
yolo_dir="${splits_dir}"

yml_text='''
  path: .  # dataset root dir
  train: images/train2017  # train images (relative to "path")
  val: images/val2017  # val images (relative to "path")
  test:
  nc: 1
  names:
    0: page
'''

db_path="$(get_1800x1200_uptonow_db_path ${campaign_id} ${in_version}).page.db"
if [ $dry_run_export -eq 0 ]; then

  # Remove pages, remove a bad image, rename all stamps to "stamp".
  echo "Removing stamps, renaming all pages to 'page', clipping polygons..."
  python -m shuffler \
    -i $(get_1800x1200_uptonow_db_path ${campaign_id} ${in_version}) \
    -o ${db_path} \
    filterObjectsSQL --sql "SELECT objectid FROM objects WHERE name NOT LIKE '%page%'" --delete \| \
    filterImagesSQL --sql "SELECT imagefile FROM images WHERE imagefile LIKE '%37-691-231.JPG'" \| \
    clipObjectsToImageBoundaries --keep_num_vertices_in_clipped_polygons
  sqlite3 ${db_path} \
    "UPDATE objects SET name='page'; SELECT name,COUNT(name) FROM objects GROUP BY name"

  # Generate splits.
  echo "Generating splits..."
  rm -rf ${splits_dir}
  ${SHUFFLER_DIR}/shuffler/tools/make_cross_validation_splits.sh \
    --input_db ${db_path} \
    --output_dir ${splits_dir} \
    --number ${k_fold} \
    --seed 0

  # Without splits.
  mkdir -p "${splits_dir}/full"
  cp ${db_path} "${splits_dir}/full/train.db"
  cp ${db_path} "${splits_dir}/full/validation.db"

  # Export to YOLO.
  echo "Export to YOLO..."
  seq_from_zero_to_n_minus_one=$(seq 0 $((${k_fold} - 1)))
  for i in ${seq_from_zero_to_n_minus_one}; do
    echo "Recreating: ${yolo_dir}/split${i}"
    rm -rf "${yolo_dir}/split${i}/images"
    rm -rf "${yolo_dir}/split${i}/labels"
    python -m shuffler -i "${splits_dir}/split${i}/train.db" --rootdir ${ROOT_DIR} \
      exportYolo --yolo_dir "${yolo_dir}/split${i}" --subset "train2017" \
        --classes "page" --symlink_images --dirtree_level_for_name 2 \
        --as_polygons
    python -m shuffler -i "${splits_dir}/split${i}/validation.db" --rootdir ${ROOT_DIR} \
      exportYolo --yolo_dir "${yolo_dir}/split${i}" --subset "val2017" \
        --classes "page" --symlink_images --dirtree_level_for_name 2 \
        --as_polygons
    echo "${yml_text}" >"${yolo_dir}/split${i}/dataset.yml"
  done

  # Export to YOLO without splits.
  echo "Export to YOLO without splits..."
  rm -rf "${yolo_dir}/full/images"
  rm -rf "${yolo_dir}/full/labels"
  python -m shuffler -i ${db_path} --rootdir ${ROOT_DIR} \
    exportYolo --yolo_dir "${yolo_dir}/full" --subset "train2017" \
      --classes "page" --symlink_images --dirtree_level_for_name 2 \
      --as_polygons
  python -m shuffler -i ${db_path} --rootdir ${ROOT_DIR} \
    exportYolo --yolo_dir "${yolo_dir}/full" --subset "val2017" \
      --classes "page" --symlink_images --dirtree_level_for_name 2 \
      --as_polygons
  echo "${yml_text}" >"${yolo_dir}/full/dataset.yml"
fi

set_id="set-page-1800x1200"

# Make experiments file.
# Follow the example at "scripts/detection_training_yolov5_jobs/experiment.example.v2.txt".
echo "campaign_id set_id run_id: ${campaign_id} ${set_id} ${run_id}"
experiments_path=$(get_detection_experiments_path ${campaign_id} ${set_id} ${run_id})
echo "Writing experiments file to ${experiments_path}"
mkdir -p "$(dirname "$experiments_path")"
echo "# Training on: ${db_path}
001;split0;16;0.01;500;0
002;split1;16;0.01;500;0
003;split2;16;0.01;500;0
004;split3;16;0.01;500;0
005;split4;16;0.01;500;0
006;full;16;0.01;500;1
#" >${experiments_path}

echo "Starting the submission script..."

${dir_of_this_file}/../scripts/detection_training_polygon_yolov5_jobs/submit.sh \
  --experiments_path ${experiments_path} \
  --splits_dir ${yolo_dir} \
  --campaign ${campaign_id} \
  --set_id ${set_id} \
  --run_id ${run_id} \
  --dry_run ${dry_run_submit}

echo "Started."
