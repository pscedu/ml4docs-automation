#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Select a new campaign from unlabeled images.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --out_version OUT_VERSION
     --num_images_in_campaign DB_NAME
     --previous_campaign_id PREVIOUS_CAMPAIGN_ID

Example:
  $PROGNAME
     --campaign_id 5
     --out_version 1
     --num_images_in_campaign 500

Options:
  --campaign_id
      (required) The campaign id.
  --out_version
      (required) The version suffix of the new database.
  --num_images_in_campaign
      (required) The number of random image in the campaign.
  --previous_campaign_id
      (optional) If not specified, infer as campaign_id-1. Use for testing".
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "out_version"
    "num_images_in_campaign"
    "previous_campaign_id"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# No defaults.

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
        --out_version)
            out_version=$2
            shift 2
            ;;
        --previous_campaign_id)
            previous_campaign_id=$2
            shift 2
            ;;
        --num_images_in_campaign)
            num_images_in_campaign=$2
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
if [ -z "$out_version" ]; then
  echo "Argument 'out_version' is required."
  exit 1
fi
if [ -z "$previous_campaign_id" ]; then
  previous_campaign_id=$((campaign_id-1))
fi
if [ -z "$num_images_in_campaign" ]; then
  echo "Argument 'num_images_in_campaign' is required."
  exit 1
fi

echo "campaign_id:            ${campaign_id}"
echo "out_version:            ${out_version}"
echo "previous_campaign_id:   ${previous_campaign_id}"
echo "num_images_in_campaign: ${num_images_in_campaign}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_ENV_DIR}/shuffler

shuffler_bin=${SHUFFLER_DIR}/shuffler.py

db_path=$(get_1800x1200_db_path ${campaign_id} ${out_version})

echo "Creating directory '${DATABASES_DIR}/campaign${campaign_id}'"
mkdir -p "${DATABASES_DIR}/campaign${campaign_id}"

# Select random images.
${shuffler_bin} \
  -i "${DATABASES_DIR}/all-1800x1200.db" \
  -o ${db_path} \
  filterImagesOfAnotherDb \
    --delete_db_file "${DATABASES_DIR}/campaign${previous_campaign_id}/campaign3to${previous_campaign_id}-6Kx4K.latest.db" \
    --use_basename \| \
  randomNImages -n ${num_images_in_campaign}

echo "Done."
