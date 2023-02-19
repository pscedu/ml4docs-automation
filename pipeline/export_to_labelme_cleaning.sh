#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Parses labelme annotations (NOT tile-based cleaning).

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version OUT_VERSION
     --subversion SUBVERSION
     --up_to_now UP_TO_NOW
     --dry_run DRY_RUN

Example:
  $PROGNAME
     --campaign_id 7
     --in_version 5
     --subversion 1
     --up_to_now 0

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version suffix of the output database.
  --subversion
      (required) The cleaning iteration id.
  --up_to_now
      (optional) 0 or 1. If 1, will export all available data for cleaning.
      If 0, will export only campaign_id. Default is 0. 
  --dry_run
      (optional) Enter 1 to NOT submit jobs. Default: "0"
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "subversion"
    "up_to_now"
    "dry_run"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
up_to_now=0
dry_run=0

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
        --subversion)
            subversion=$2
            shift 2
            ;;
        --up_to_now)
            up_to_now=$2
            shift 2
            ;;
        --dry_run)
            dry_run=$2
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
if [ -z "$subversion" ]; then
  echo "Argument 'subversion' is required."
  exit 1
fi

echo "campaign_id:  ${campaign_id}"
echo "in_version:   ${in_version}"
echo "subversion:   ${subversion}"
echo "up_to_now:    ${up_to_now}"
echo "dry_run:      ${dry_run}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"

# Folder with temporary images.
folder="cleaning-v${in_version}.${subversion}"
mkdir -p "${DATABASES_DIR}/campaign${campaign_id}/labelme/${folder}"

if [ ${up_to_now} -eq 0 ]; then
  get_db_name_func="get_6Kx4K_db_path"
else
  get_db_name_func="get_6Kx4K_uptonow_db_path"
fi

# If this is the first cleaning, make a copy of the database from ${in_version}
# to ${in_version}.${prev_subversion}. Used for export and later for import.
prev_subversion=$((${subversion}-1))
in_db_path=$(${get_db_name_func} ${campaign_id} ${in_version}.${prev_subversion})
if [ ${subversion} -eq 1 ]; then
  cp $(${get_db_name_func} ${campaign_id} ${in_version}) ${in_db_path}
fi

${dir_of_this_file}/../scripts/collages_for_cleaning/submit.sh \
  --campaign_id ${campaign_id} \
  --in_db_name $(basename ${in_db_path}) \
  --folder ${folder} \
  --dry_run ${dry_run}

echo "Done."
