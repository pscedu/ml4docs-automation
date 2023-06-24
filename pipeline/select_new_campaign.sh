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

Example:
  $PROGNAME
     --campaign_id 5
     --out_version 1
     --num_images_in_campaign 500

Options:
  --campaign_id
      (required) The campaign id.
  --num_images_in_campaign
      (required) The number of random image in the campaign.
  --out_version
      (optional) The version suffix of the new database. Default is 1.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "out_version"
    "num_images_in_campaign"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
out_version=1

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
if [ -z "$num_images_in_campaign" ]; then
  echo "Argument 'num_images_in_campaign' is required."
  exit 1
fi

prev_campaign_id=$((${campaign_id}-1))

echo "campaign_id:            ${campaign_id}"
echo "out_version:            ${out_version}"
echo "prev_campaign_id:       ${prev_campaign_id}"
echo "num_images_in_campaign: ${num_images_in_campaign}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh
source ${dir_of_this_file}/../path_generator.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"

db_path=$(get_1800x1200_db_path ${campaign_id} ${out_version})

echo "Creating directory '${DATABASES_DIR}/campaign${campaign_id}'"
mkdir -p "${DATABASES_DIR}/campaign${campaign_id}"

# Select random images.
python -m shuffler \
  -i $(get_1800x1200_all_db_path) \
  -o ${db_path} \
  --rootdir ${ROOT_DIR} \
  filterImagesViaAnotherDb \
    --ref_db_file $(get_1800x1200_uptonow_db_path ${prev_campaign_id} 'latest') \
    --delete \
    --dirtree_level 1 \| \
  randomNImages -n ${num_images_in_campaign} \| \
  filterBadImages

sqlite3 ${db_path} "
  UPDATE images SET name='${campaign_id}';
  INSERT INTO properties(objectid,key,value) SELECT objectid,'campaign',images.name
         FROM objects INNER JOIN images ON objects.imagefile = images.imagefile
  "

log_db_version ${campaign_id} ${out_version} "Images are selected for a new campaign."
echo "Done."
