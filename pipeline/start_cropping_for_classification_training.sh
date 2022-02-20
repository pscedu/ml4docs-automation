#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Start the job of cropping stamps out of a database for the purpose of cleaning.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version IN_VERSION
     --size SIZE
     --expand_percent EXPAND_PERCENT
     --dry_run_submit DRY_RUN_SUBMIT

Example:
  $PROGNAME
     --campaign_id 7
     --in_version 7

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version suffix of the database to crop.
  --expand_percent
      (optional) Stamps are expanded to be further cropped by classification.
                 Should be the same as expansion for training. Default: 0.5.
  --size
      (optional) Resized to squares of 'size x size' after crop. Default: 260.
  --dry_run_submit
      (optional) Enter 1 to NOT submit jobs. Default: "0"
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "expand_percent"
    "size"
    "dry_run_submit"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
expand_percent=0.5
dry_run_submit=0
size=260

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
        --expand_percent)
            expand_percent=$2
            shift 2
            ;;
        --size)
            size=$2
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
echo "expand_percent:         ${expand_percent}"
echo "size:                   ${size}"
echo "dry_run_submit:         ${dry_run_submit}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}

shuffler_bin=${SHUFFLER_DIR}/shuffler.py

# Steps: 1) move to 6Kx4K, 2) enlarge stamps.
out_version="${in_version}.expand${expand_percent}"
out_db_file=$(get_6Kx4K_uptonow_db_path ${campaign_id} ${out_version})
${shuffler_bin} \
    -i ${in_db_file} \
    -o ${out_db_file} \
    expandObjects --expand_perc ${expand_percent}

${dir_of_this_file}/../scripts/crop_stamps_job/submit.sh \
  --campaign_id ${campaign_id} \
  --in_version ${out_version} \
  --up_to_now "1" \
  --size ${size} \
  --dry_run ${dry_run_submit}

