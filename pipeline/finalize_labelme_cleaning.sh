#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
A simple script to finalize cleaning. Promote files 6Kx4K and 1800x1200 
up-to-now from the last subversion to the next version.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version IN_VERSION
     --subversion SUBVERSION
     --out_version OUT_VERSION

Example:
  $PROGNAME
     --campaign_id 7
     --in_version 7

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version suffix of the output database.
  --subversion
      (optional) A number that correponds to the cleaning iteration.
                 If specified, will promote this subversion as "clean".
                 Otherwise, will infer the latest subversion.
  --out_version
      (optional) If specified, will be promoted to this version. 
                 Otherwise, will use in_version + 1.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "out_version"
    "subversion"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
subversion='?'  # This will get the latest subversion via "ls | tail -n 1".

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
  out_version=$((${in_version} + 1))
  echo "Argument 'out_version' is not provided. Will use ${out_version}."
fi
if (( "$out_version" <= $in_version )); then
  echo "Argument 'out_version'=$out_version must be > 'in_version'=$in_version."
  exit 1
fi

echo "campaign_id:            ${campaign_id}"
echo "in_version:             ${in_version}"
echo "out_version:            ${out_version}"
echo "subversion:             ${subversion}"

# The end of the parsing code.
################################################################################

# Import all constants. Need it to get subversion. 
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

# The path to promote.
in_6Kx4K_uptonow_path=$(ls -1 $(get_6Kx4K_uptonow_db_path ${campaign_id} ${in_version}.${subversion}) | tail -n 1)
if [ -z "$in_6Kx4K_uptonow_path" ]; then
  echo "Failed to set in_6Kx4K_uptonow_path. Exit."
  exit 1
fi

# The new paths.
out_6Kx4K_uptonow_path=$(get_6Kx4K_uptonow_db_path ${campaign_id} ${out_version})
echo "Linking to database: ${out_6Kx4K_uptonow_path}"
rm -f ${out_6Kx4K_uptonow_path}
ln -s ${in_6Kx4K_uptonow_path} ${out_6Kx4K_uptonow_path}

# The path to promote.
in_1800x1200_uptonow_path=$(ls -1 $(get_1800x1200_uptonow_db_path ${campaign_id} ${in_version}.${subversion}) | tail -n 1)
if [ -z "$in_1800x1200_uptonow_path" ]; then
  echo "Failed to set in_1800x1200_uptonow_path. Exit."
  exit 1
fi

# The new paths.
out_1800x1200_uptonow_path=$(get_1800x1200_uptonow_db_path ${campaign_id} ${out_version})
echo "Linking to database: ${out_1800x1200_uptonow_path}"
rm -f ${out_1800x1200_uptonow_path}
ln -s ${in_1800x1200_uptonow_path} ${out_1800x1200_uptonow_path}


${dir_of_this_file}/../scripts/assign_latest_database_version.sh \
  --campaign_id ${campaign_id} \
  --in_version ${out_version}

log_db_version(${campaign_id} ${out_version} "Promoted after cleaning rounds are done.")
echo "Done."
