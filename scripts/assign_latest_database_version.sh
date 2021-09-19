#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
A simple script that creates symlinks in the form "campaignX.Y.vlatest.db".
Symlinks point to the provided version. They are used by subsequent campaigns.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version IN_VERSION
     --dry_run DRY_RUN

Example:
  $PROGNAME
     --campaign_id 7
     --in_version 7

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version suffix of the input database. 
      If empty, will use the actually latest.
  --dry_run
      (optional) Enter 1 to only print without creating links. Default: "0"
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "dry_run"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
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

echo "campaign_id:            ${campaign_id}"
echo "in_version:             ${in_version}"
echo "dry_run:                ${dry_run}"

# The end of the parsing code.
################################################################################

# Import all constants. Need it to get subversion. 
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

cd "${DATABASES_DIR}/campaign${campaign_id}"

in_path=$(get_1800x1200_db_path ${campaign_id} ${in_version})
if test -f "${in_path}"; then
  ln_path=$(get_1800x1200_db_path ${campaign_id} "latest")
  rm -f ${ln_path}
  echo "Linking '${in_path}' to '${ln_path}'."
  if [ ${dry_run} == "0" ]; then
    ln -s $(basename ${in_path}) $(basename ${ln_path})
  fi
else
  echo "Failed to find ${in_path}."
fi

in_path=$(get_6Kx4K_db_path ${campaign_id} ${in_version})
if test -f "${in_path}"; then
  ln_path=$(get_6Kx4K_db_path ${campaign_id} "latest")
  rm -f ${ln_path}
  echo "Linking '${in_path}' to '${ln_path}'."
  if [ ${dry_run} == "0" ]; then
    ln -s $(basename ${in_path}) $(basename ${ln_path})
  fi
else
  echo "Failed to find ${in_path}."
fi

in_path=$(get_1800x1200_uptonow_db_path ${campaign_id} ${in_version})
if test -f "${in_path}"; then
  ln_path=$(get_1800x1200_uptonow_db_path ${campaign_id} "latest")
  rm -f ${ln_path}
  echo "Linking '${in_path}' to '${ln_path}'."
  if [ ${dry_run} == "0" ]; then
    ln -s $(basename ${in_path}) $(basename ${ln_path})
  fi
else
  echo "Failed to find ${in_path}."
fi

in_path=$(get_6Kx4K_uptonow_db_path ${campaign_id} ${in_version})
if test -f "${in_path}"; then
  ln_path=$(get_6Kx4K_uptonow_db_path ${campaign_id} "latest")
  rm -f ${ln_path}
  echo "Linking '${in_path}' to '${ln_path}'."
  if [ ${dry_run} == "0" ]; then
    ln -s $(basename ${in_path}) $(basename ${ln_path})
  fi
else
  echo "Failed to find ${in_path}."
fi

cd -
