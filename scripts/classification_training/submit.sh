#!/bin/bash

set -e

# TODO: Add "run".

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
This script starts a batch job that trains a classification model.

Usage:
  $PROGNAME
    --campaign_id CAMPAIGN_ID
    --in_version IN_VERSION
    --set SET_ID
    --run RUN_ID

Example:
  $PROGNAME
    --campaign_id 6
    --in_version 7
    --set_id="set-stamp-1800x1200"
    --run_id 0

Options:
  --campaign_id
      (required) Id of campaign. Example: "6"
  --in_version
      (required) The version suffix of the input database.
  --set_id
      (required) Id of set. Example: 3.
  --run_id
      (required) Id of run. Example: 0.
  --dry_run
      (optional) Enter 1 to NOT submit jobs. Default: "0"
  -h|--help
      Print usage and exit.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "set_id"
    "run_id"
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
        --set_id)
            set_id=$2
            shift 2
            ;;
        --run_id)
            run_id=$2
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
if [ -z "$set_id" ]; then
  echo "Argument 'set' is required."
  exit 1
fi
if [ -z "$run_id" ]; then
  echo "Argument 'run' is required."
  exit 1
fi

echo "campaign_id:      ${campaign_id}"
echo "in_version:       ${in_version}"
echo "set_id:           $set_id"
echo "run_id:           $run_id"
echo "dry_run:          ${dry_run_submit}"

# The end of the parsing code.
################################################################################

# Import all constants. Assumes this file is in scripst/train_classification.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../../constants.sh

template_path="${dir_of_this_file}/template.sbatch"
if [ ! -f "${template_path}" ]; then
    echo "Job template does not exist at '${template_path}'"
    exit 1
fi

in_db_file=$(get_uptonow_cropped_db_path ${campaign_id} "${in_version}")
ls ${in_db_file}

output_dir="${CLASSIFICATION_DIR}/campaign${campaign_id}/${set_id}/run${run_id}"
mkdir -p ${output_dir}

# Stem of the batch job (without extension).
batch_jobs_dir="${output_dir}/batch_jobs"
mkdir -p "${batch_jobs_dir}"
batch_job_path_stem="${batch_jobs_dir}/train_classification"

sed \
    -e "s|DB_FILE|${in_db_file}|g" \
    -e "s|ROOT_DIR|${ROOT_DIR}|g" \
    -e "s|SHUFFLER_DIR|${SHUFFLER_DIR}|g" \
    -e "s|OUTPUT_DIR|${output_dir}|g" \
    -e "s|OLTR_DIR|${OLTR_DIR}|g" \
    -e "s|CONDA_INIT_SCRIPT|${CONDA_INIT_SCRIPT}|g" \
    -e "s|CONDA_OLTR_ENV|${CONDA_OLTR_ENV}|g" \
    ${template_path} > "${batch_job_path_stem}.sbatch"
status=$?
if [ ${status} -ne 0 ]; then
    echo "Failed to use the template from '${template_path}'"
    exit ${status}
fi

echo "Wrote a job file to '${batch_job_path_stem}.sbatch' without submitting it."
if [ ${dry_run} == "0" ]; then
    JID=$(sbatch -A ${ACCOUNT} \
        --output="${batch_job_path_stem}.out" \
        --error="${batch_job_path_stem}.err" \
        "${batch_job_path_stem}.sbatch")
    echo $JID
    JOB_ID=${JID##* }
    touch "${batch_jobs_dir}/job_ids.txt"
    echo `date`" "${JOB_ID} >> "${batch_jobs_dir}/job_ids.txt"
fi
