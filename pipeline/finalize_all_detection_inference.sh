#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Make a video and classify pages.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version IN_VERSION
     --out_version OUT_VERSION

Example:
  $PROGNAME
     --campaign_id 8
     --in_version 4
     --out_version 5

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version of the original database with detected stamps and pages.
  --out_version
      (required) The version of the output non-cropped database.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "out_version"
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
        --out_version)
            out_version=$2
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

echo "campaign_id:            ${campaign_id}"
echo "in_version:             ${in_version}"
echo "out_version:            ${out_version}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"


in_db_path=$(get_1800x1200_db_path ${campaign_id} "${in_version}")
out_db_path=$(get_1800x1200_db_path ${campaign_id} ${out_version})

ls ${in_db_path}

echo "Number of detections:"
sqlite3 ${in_db_path} "SELECT name,COUNT(1) FROM objects GROUP BY name"

shuffler_bin=${SHUFFLER_DIR}/shuffler.py

${shuffler_bin} -i ${in_db_path} -o ${out_db_path} classifyPages

${shuffler_bin} -i ${out_db_path} --rootdir ${ROOT_DIR} \
  writeMedia \
    --media "video" \
    --image_path "${out_db_path}.avi" \
    --with_objects \
    --with_imageid \
    --overwrite

echo "Done."
