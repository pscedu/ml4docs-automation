#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
This script starts a batch job that crops stamp objects (not pages) from a database.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --version IN_VERSION
     --size SIZE

Example:
  $PROGNAME
     --campaign_id 6
     --in_version 7
     --up_to_now 0
     --size 260

Options:
  --campaign_id
      (required) Id of campaign. Example: "5"
  --in_version
      (required) The version suffix of the database to crop.
  --up_to_now
      (required) If "0" only this campaign, otherwise all campaigns.
  --size
      (optional) If specified, resize to this size, otherwise, keep the original size.
  --dry_run
      (optional) Enter 1 to NOT submit jobs. Default: "0"
  -h|--help
      Print usage and exit.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "up_to_now"
    "size"
    "dry_run"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
size=""
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
        --up_to_now)
            up_to_now=$2
            shift 2
            ;;
        --size)
            size=$2
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
  echo "Argument 'campaign' is required."
  exit 1
fi
if [ -z "$in_version" ]; then
  echo "Argument 'in_version' is required."
  exit 1
fi
if [ -z "$up_to_now" ]; then
  echo "Argument 'up_to_now' is required."
  exit 1
fi

echo "campaign_id:            ${campaign_id}"
echo "in_version:             ${in_version}"
echo "up_to_now:              ${up_to_now}"
echo "size:                   ${size}"
echo "dry_run:                ${dry_run}"

# The end of the parsing code.
################################################################################

# Import all constants. Assumes this file is in scripst/crop_stamps_job.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../../constants.sh

dir_of_this_file=$(dirname $(readlink -f $0))
template_path="${dir_of_this_file}/template.sbatch"
if [ ! -f "${template_path}" ]; then
    echo "Job template does not exist at '${template_path}'"
    exit 1
fi

out_version="${in_version}.size${size}"

if [ ${up_to_now} == "0" ]; then
  in_db_file=$(get_6Kx4K_db_path ${campaign_id} ${in_version})
  cropped_db_file=$(get_cropped_db_path ${campaign_id} ${out_version})
else
  in_db_file=$(get_6Kx4K_uptonow_db_path ${campaign_id} ${in_version})
  cropped_db_file=$(get_uptonow_cropped_db_path ${campaign_id} ${out_version})
fi

ls ${in_db_file}

# Stem of the batch job (without extension).
batch_job_dir="${DATABASES_DIR}/campaign${campaign_id}/batch_jobs"
mkdir -p ${batch_job_dir}
batch_job_path_stem="${batch_job_dir}/crop-objects-campaign${campaign_id}-v${out_version}.uptonow${up_to_now}"

sed \
    -e "s|CAMPAIGN_ID|$campaign_id|g" \
    -e "s|IN_DB_FILE|${in_db_file}|g" \
    -e "s|OUT_CROPPED_DB_FILE|${cropped_db_file}|g" \
    -e "s|SIZE|${size}|g" \
    -e "s|ROOT_DIR|${ROOT_DIR}|g" \
    -e "s|SHUFFLER_DIR|${SHUFFLER_DIR}|g" \
    -e "s|CONDA_INIT_SCRIPT|${CONDA_INIT_SCRIPT}|g" \
    -e "s|CONDA_SHUFFLER_ENV|${CONDA_SHUFFLER_ENV}|g" \
    ${template_path} > "${batch_job_path_stem}.sbatch"
status=$?
if [ ${status} -ne 0 ]; then
    echo "Failed to use the template from '${template_path}'"
    exit ${status}
fi

echo "Wrote ready job to '${batch_job_path_stem}.sbatch'"
if [ ${dry_run} == "0" ]; then
    sbatch -A ${ACCOUNT} \
        --output="${batch_job_path_stem}.out" \
        --error="${batch_job_path_stem}.err" \
        "${batch_job_path_stem}.sbatch"
fi
