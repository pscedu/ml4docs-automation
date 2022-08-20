#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Start stamp-detection model training.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version IN_VERSION
     --k_fold K_FOLD
     --run_id RUN_ID
     --dry_run_submit DRY_RUN_SUBMIT

Example:
  $PROGNAME
     --campaign_id 7
     --in_version 7

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version suffix of the input database.
  --k_fold
      (optional) Will perform k-fold validation. Default is 5.
  --run_id
      (optional) The try id. Use if the 0th try failed. Default is 0.
  --dry_run_submit
      (optional) Enter 1 to NOT submit jobs. Default: "0"
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "k_fold"
    "run_id"
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
echo "dry_run_submit:         ${dry_run_submit}"


# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"

shuffler_bin=${SHUFFLER_DIR}/shuffler.py

# Will be used to name dirs and databases.
stem="campaign3to${campaign_id}-1800x1200.v${in_version}.stamp"
splits_dir="${DATABASES_DIR}/campaign${campaign_id}/splits/${stem}"


if [ $dry_run_export -eq 0 ]; then

  # Remove pages, remove a bad image, rename all stamps to "stamp".
  echo "Removing stamps, renaming all pages to 'page'..."
  db_path="$(get_1800x1200_uptonow_db_path ${campaign_id} ${in_version}).stamp.db"
  ${shuffler_bin} \
    -i $(get_1800x1200_uptonow_db_path ${campaign_id} ${in_version}) \
    -o ${db_path} \
    filterObjectsSQL --sql "SELECT objectid FROM objects WHERE name LIKE '%page%'" \| \
    filterImagesSQL --sql "SELECT imagefile FROM images WHERE imagefile LIKE '%37-691-231.JPG'"
  sqlite3 ${db_path} \
    "UPDATE objects SET name='stamp'; SELECT name,COUNT(name) FROM objects GROUP BY name"

  # Generate splits.
  echo "Generating splits..."
  rm -rf ${splits_dir}
  ${SHUFFLER_DIR}/tools/MakeCrossValidationSplits.sh \
    --input_db ${db_path} \
    --output_dir ${splits_dir} \
    --number ${k_fold} \
    --seed 0 \
    --shuffler_bin ${shuffler_bin}

  # Without splits.
  mkdir -p "${splits_dir}/full"
  cp ${db_path} "${splits_dir}/full/train.db"
  cp ${db_path} "${splits_dir}/full/validation.db"

fi

set_id="set-stamp-1800x1200"

# Make experiments file. 
# Follow the example at "scripts/detection_training_yolov5_jobs/experiment.example.v2.txt".
echo "Writing experiments file..."
experiments_path=$(get_detection_experiments_path ${campaign_id} ${set_id} ${run_id})
echo "#
001;split0;4;0.0001;100;1
002;split1;4;0.0001;100;1
003;split2;4;0.0001;100;1
004;split3;4;0.0001;100;1
005;split4;4;0.0001;100;1
006;full;4;0.0001;100;0
007;split0;4;0.001;100;1
008;split1;4;0.001;100;1
009;split2;4;0.001;100;1
010;split3;4;0.001;100;1
011;split4;4;0.001;100;1
012;full;4;0.001;100;0
#" > ${experiments_path}

echo "Starting the submission script..."

${dir_of_this_file}/../scripts/detection_training_yolov5_jobs/submit.sh \
  --experiments_path ${experiments_path} \
  --splits_dir ${splits_dir} \
  --campaign ${campaign_id} \
  --set_id ${set_id} \
  --run_id ${run_id} \
  --dry_run ${dry_run_submit}

echo "Done."
