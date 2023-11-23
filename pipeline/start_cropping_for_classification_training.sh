#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Start the job of cropping stamps out of a database to train classification.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version IN_VERSION
     --expand_fraction EXPAND_FRACTION (0.5, 0.2, 0, etc)
     --size SIZE
     --in_front_pages {0,1}
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
  --expand_fraction
      (optional) Stamps are expanded to be further cropped by classification.
                 Should be the same as expansion for training. Default: 0.5.
  --size
      (optional) Resized to squares of 'size x size' after crop. Default: 260.
  --in_front_pages
      (optional) Enter 1 to keep only stamps inside front pages.
  --dry_run_submit
      (optional) Enter 1 to NOT submit jobs. Default: "0"
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "expand_fraction"
    "size"
    "in_front_pages"
    "dry_run_submit"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
expand_fraction=0.5
size=260
in_front_pages=0
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
        --expand_fraction)
            expand_fraction=$2
            shift 2
            ;;
        --size)
            size=$2
            shift 2
            ;;
        --in_front_pages)
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
if [ ${expand_fraction} == "0" ]; then
  echo "Argument 'expand_fraction' can not be 0."
  exit 1
fi

echo "campaign_id:            ${campaign_id}"
echo "in_version:             ${in_version}"
echo "expand_fraction:        ${expand_fraction}"
echo "size:                   ${size}"
echo "in_front_pages:         ${in_front_pages}"
echo "dry_run_submit:         ${dry_run_submit}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh
source ${dir_of_this_file}/../path_generator.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}

in_db_file=$(get_6Kx4K_uptonow_db_path ${campaign_id} ${in_version})

# 1) Maybe filter only inside front pages, 2) move to 6Kx4K, 3) enlarge stamps.
if [ ${in_front_pages} -eq 0 ]; then
  out_version="${in_version}.expand${expand_fraction}"
  condition="TRUE"
else
  out_version="${in_version}.expand${expand_fraction}.inFrontPages"
  condition="\"name IN ('page_l', 'name_r', 'name')\""
fi
out_db_file=$(get_6Kx4K_uptonow_db_path ${campaign_id} ${out_version})
python -m shuffler \
    -i ${in_db_file} \
    -o ${out_db_file} \
    filterObjectsInsideCertainObjects \
      --keep --where_shadowing_objects ${condition} \| \
    recordPositionOnPage \| \
    expandObjects --expand_fraction ${expand_fraction}

${dir_of_this_file}/../scripts/crop_stamps_job/submit.sh \
  --campaign_id ${campaign_id} \
  --in_version ${out_version} \
  --up_to_now "1" \
  --size ${size} \
  --dry_run ${dry_run_submit}

echo "Done."
