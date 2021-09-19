#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Prints some info about the campaign and writes some visualization.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version IN_VERSION

Example:
  $PROGNAME
     --campaign_id 7
     --in_version 5

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version suffix of the input database.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
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
        --in_version)
            in_version=$2
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

echo "campaign_id:  ${campaign_id}"
echo "in_version:   ${in_version}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_ENV_DIR}/shuffler
echo "Conda environment is activated: '${CONDA_ENV_DIR}/shuffler'"

in_db_path=$(get_1800x1200_db_path ${campaign_id} ${in_version})
video_dir="${DATABASES_DIR}/campaign${campaign_id}/visualization"
video_bare_path="${DATABASES_DIR}/campaign${campaign_id}/visualization/campaign${campaign_id}.v${in_version}.avi"
video_annotated_path="${DATABASES_DIR}/campaign${campaign_id}/visualization/campaign${campaign_id}-withstamps.v${in_version}.avi"

echo "Working with file: ${db_path}"

echo "Stamp names and their count in this campaign:"
sqlite3 ${db_path} \
  "SELECT name,COUNT(1) FROM objects WHERE name NOT LIKE '%page%' GROUP BY name"

echo "Number of stamps in this campaign:"
sqlite3 ${db_path} "SELECT COUNT(1) FROM objects WHERE name LIKE '%page%'"

echo "Number of pages in this campaign:"
sqlite3 ${db_path} "SELECT COUNT(1) FROM objects WHERE name NOT LIKE '%page%'"

# Write the video.
mkdir -p ${video_dir}
${shuffler_bin} \
  -i ${db_path} --rootdir ${ROOT_DIR} --logging 30 \
  writeMedia \
    --media video \
    --image_path ${video_bare_path} \
    --overwrite \| \
  writeMedia \
    --media video \
    --image_path ${video_annotated_path} \
    --with_objects \
    --overwrite

echo "Done."
