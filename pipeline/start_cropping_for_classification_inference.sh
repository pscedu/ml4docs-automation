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
     --out_version OUT_VERSION
     --size SIZE
     --expand_fraction EXPAND_FRACTION (0.5, 0.2, 0, etc)
     --dry_run_submit DRY_RUN_SUBMIT

Example:
  $PROGNAME
     --campaign_id 8
     --in_version 3

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version suffix of the database to crop.
  --out_version
      (required) The version suffix of the filtered (and also cropped) database.
  --expand_fraction
      (optional) Stamps are expanded to be further cropped by classificsation.
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
    "out_version"
    "expand_fraction"
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
expand_fraction=0.5
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
        --out_version)
            out_version=$2
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
if [ -z "$out_version" ]; then
  out_version=$((in_version+1))
  echo "Automatically setting out_version to ${out_version}."
fi
if [ ${expand_fraction} == "0" ]; then
  echo "Argument 'expand_fraction' can not be 0."
  exit 1
fi

echo "campaign_id:            ${campaign_id}"
echo "in_version:             ${in_version}"
echo "out_version:            ${out_version}"
echo "expand_fraction:        ${expand_fraction}"
echo "size:                   ${size}"
echo "dry_run_submit:         ${dry_run_submit}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh
source ${dir_of_this_file}/../path_generator.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}

in_1800x1200_path=$(get_1800x1200_db_path ${campaign_id} ${in_version})
out_6Kx4K_expanded_path=$(get_6Kx4K_db_path ${campaign_id} ${out_version}.expand${expand_fraction})

ls ${in_1800x1200_path}


# Steps: 1) move to 6Kx4K, 3) expand stamps, 4) start cropping.

python -m shuffler \
    -i ${in_1800x1200_path} \
    -o ${out_6Kx4K_expanded_path} \
    --rootdir ${ROOT_DIR} \
    recordPositionOnPage \| \
    moveMedia --image_path "original_dataset" --level 2 --adjust_size \| \
    expandObjects --expand_fraction ${expand_fraction}

${dir_of_this_file}/../scripts/crop_stamps_job/submit.sh \
  --campaign_id ${campaign_id} \
  --in_version "${out_version}.expand${expand_fraction}" \
  --up_to_now "0" \
  --size ${size} \
  --dry_run ${dry_run_submit}

log_db_version ${campaign_id} ${out_version} \
  "Recorded position on page and expanded objects by start_cropping_for_classification_inference."
echo "Done."
