#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Start training of stamp classification.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version IN_VERSION
     --k_fold K_FOLD
     --set_id SET_ID
     --run_id RUN_ID
     --dry_run_split DRY_RUN_SPLIT
     --dry_run_submit DRY_RUN_SUBMIT

Example:
  $PROGNAME
     --campaign_id 6
     --in_version 7

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version suffix of the input database.
  --k_fold
      (optional) Will perform k-fold validation. Default is 5.
  --set_id
      (optional) The id of cropped database. Use if want non-standard data.
                 Default: "expand0.5.size260". Look up options in dir "crops".
  --run_id
      (optional) The try id. Use if the 0th try failed. Default is 0.
  --dry_run_split
      (optional) Enter 1 to NOT create splits. Use it when testing submission scrips. Default: "0"
  --dry_run_submit
      (optional) Enter 1 to NOT submit jobs. Default: "0"
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "k_fold"
    "set_id"
    "run_id"
    "dry_run_submit"
    "dry_run_split"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
set_id="expand0.5.size260"
k_fold=5
run_id=0
dry_run_submit=0
dry_run_split=0

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
        --set_id)
            set_id=$2
            shift 2
            ;;
        --run_id)
            run_id=$2
            shift 2
            ;;
        --dry_run_split)
            dry_run_split=$2
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
echo "set_id:                 ${set_id}"
echo "run_id:                 ${run_id}"
echo "dry_run_split:          ${dry_run_split}"
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

in_db_path=$(get_uptonow_cropped_db_path ${campaign_id} "${in_version}.${set_id}")

filename=$(basename -- ${in_db_path})
stem="${filename%.*}"
splits_dir="${DATABASES_DIR}/campaign${campaign_id}/crops/splits/${stem}"

# Generate splits.
if [ ${dry_run_split} -eq  "0" ]; then
    echo "Generating splits..."
    rm -rf ${splits_dir}
    ${SHUFFLER_DIR}/shuffler/tools/make_cross_validation_splits.sh \
    --input_db ${in_db_path} \
    --output_dir ${splits_dir} \
    --number ${k_fold} \
    --seed 0

    # Without splits.
    mkdir -p "${splits_dir}/full"
    cp ${in_db_path} "${splits_dir}/full/train.db"
    cp ${in_db_path} "${splits_dir}/full/validation.db"
fi

# Make experiments file. 
# Follow the example at "scripts/classification_training/experiments.example.txt".
experiments_path=$(get_classification_experiments_path ${campaign_id} ${set_id} ${run_id})
mkdir -p $(dirname ${experiments_path})
echo "Writing experiments file to ${experiments_path}"
echo "# in_db_path: ${in_db_path}
001;split0;_resnet152;0
002;split1;_resnet152;0
003;split2;_resnet152;0
004;split3;_resnet152;0
005;split4;_resnet152;0
006;full;_resnet152;1
" > ${experiments_path}

echo "Starting the submission script..."

${dir_of_this_file}/../scripts/classification_training/submit.sh \
  --experiments_path ${experiments_path} \
  --splits_dir ${splits_dir} \
  --campaign_id ${campaign_id} \
  --set_id ${set_id} \
  --run_id ${run_id} \
  --dry_run ${dry_run_submit}
