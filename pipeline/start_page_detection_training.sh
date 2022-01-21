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
     --steps_per_epoch STEPS_PER_EPOCH
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
  --steps_per_epoch
      (optional) Number of steps in epoch.
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
    "steps_per_epoch"
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
steps_per_epoch=250
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
        --steps_per_epoch)
            steps_per_epoch=$2
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

previous_campaign_id=$((campaign_id-1))

echo "campaign_id:            ${campaign_id}"
echo "previous_campaign_id:   ${previous_campaign_id}"
echo "in_version:             ${in_version}"
echo "k_fold:                 ${k_fold}"
echo "run_id:                 ${run_id}"
echo "steps_per_epoch:        ${steps_per_epoch}"
echo "dry_run_export:         ${dry_run_export}"
echo "dry_run_submit:         ${dry_run_submit}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_ENV_DIR}/shuffler
echo "Conda environment is activated: '${CONDA_ENV_DIR}/shuffler'"

shuffler_bin=${SHUFFLER_DIR}/shuffler.py

# Will be used to name dirs and databases.
stem="campaign3to${campaign_id}-1800x1200.v${in_version}.page"
split_dir="${DATABASES_DIR}/campaign${campaign_id}/splits/${stem}"
coco_dir="${DETECTION_DIR}/campaign${campaign_id}/splits/${stem}"


if [ $dry_run_export -eq 0 ]; then

  # Remove stamps, remove a bad image, rename all pages to "page".
  echo "Removing stamps, renaming all pages to 'page'..."
  db_path="$(get_1800x1200_uptonow_db_path ${campaign_id} ${in_version}).page.db"
  ${shuffler_bin} \
    -i $(get_1800x1200_uptonow_db_path ${campaign_id} ${in_version}) \
    -o ${db_path} \
    filterObjectsSQL --sql "SELECT objectid FROM objects WHERE name NOT LIKE '%page%'" \| \
    filterImagesSQL --sql "SELECT imagefile FROM images WHERE imagefile LIKE '%37-691-231.JPG'"
  sqlite3 ${db_path} \
    "UPDATE objects SET name='page'; SELECT name,COUNT(name) FROM objects GROUP BY name"

  # Generate splits.
  echo "Generating splits..."
  rm -rf ${split_dir}
  ${SHUFFLER_DIR}/tools/MakeCrossValidationSplits.sh \
    --input_db ${db_path} \
    --output_dir ${split_dir} \
    --number ${k_fold} \
    --seed 0 \
    --shuffler_bin ${shuffler_bin}

  # Export to COCO.
  echo "Export to COCO..."
  rm -rf ${coco_dir}
  mkdir -p ${coco_dir}
  seq_from_zero_to_n_minus_one=$(seq 0 $((${k_fold} - 1)))
  for i in ${seq_from_zero_to_n_minus_one}; do
    ${shuffler_bin} -i "${split_dir}/split${i}/train.db" --rootdir ${ROOT_DIR} \
      exportCoco --coco_dir "${coco_dir}/split${i}" --subset "train2017" --copy_images 
    ${shuffler_bin} -i "${split_dir}/split${i}/validation.db" --rootdir ${ROOT_DIR} \
      exportCoco --coco_dir "${coco_dir}/split${i}" --subset "val2017" --copy_images 
  done

  # Export to COCO without splits.
  echo "Export to COCO without splits..."
  mkdir -p ${coco_dir}/full
  ${shuffler_bin} -i ${db_path} --rootdir ${ROOT_DIR} \
      exportCoco --coco_dir "${coco_dir}/full" --subset "train2017" --copy_images 
  ${shuffler_bin} -i ${db_path} --rootdir ${ROOT_DIR} \
      exportCoco --coco_dir "${coco_dir}/full" --subset "val2017" --copy_images

fi

# Make experiments file. 
# Follow the example at "scripts/detection_training_retinanet_jobs/experiment.example.v2.txt".
echo "Writing experiments file..."
experiments_path="${coco_dir}/experiments.txt"
echo "001;split0;2;0.0001;50;0
002;split1;2;0.0001;50;0
003;split2;2;0.0001;50;0
004;split3;2;0.0001;50;0
005;split4;2;0.0001;50;0
006;full;2;0.0001;50;1" > ${experiments_path}

# Start a job.
echo "Submitting jobs..."

${dir_of_this_file}/../scripts/detection_training_retinanet_jobs/submit.sh \
  --campaign ${campaign_id} \
  --experiments_path ${experiments_path} \
  --splits_dir ${coco_dir} \
  --set "set-page-1800x1200" \
  --run ${run_id} \
  --steps_per_epoch ${steps_per_epoch} \
  --dry_run ${dry_run_submit}

echo "Started."
