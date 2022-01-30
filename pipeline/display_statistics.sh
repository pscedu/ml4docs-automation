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
     --up_to_now UP_TO_NOW

Example:
  $PROGNAME
     --campaign_id 7
     --in_version 5
     --up_to_now 0

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version suffix of the input database.
  --up_to_now
      (optional) 0 or 1. If 1, will export all available data for cleaning.
      If 0, will analyze only this campaign_id. Default is 0. 
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "up_to_now"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
up_to_now=0

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
        --up_to_now)
            up_to_now=$2
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
echo "up_to_now:    ${up_to_now}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_ENV_DIR}/shuffler
echo "Conda environment is activated: '${CONDA_ENV_DIR}/shuffler'"


if [ ${up_to_now} -eq 0 ]; then
  get_db_name_func="get_1800x1200_db_path"
else
  get_db_name_func="get_1800x1200_uptonow_db_path"
fi

in_db_path=$(${get_db_name_func} ${campaign_id} ${in_version})

echo "Working with database: ${in_db_path}"

echo "Stamp names and their count:"
sqlite3 ${in_db_path} \
  "SELECT name,COUNT(1) FROM objects WHERE name NOT LIKE '%page%' GROUP BY name"

echo "Number of stamps:"
sqlite3 ${in_db_path} "SELECT COUNT(1) FROM objects WHERE name LIKE '%page%'"

echo "Number of pages:"
sqlite3 ${in_db_path} "SELECT COUNT(1) FROM objects WHERE name NOT LIKE '%page%'"


echo "Done."
