#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
This script starts a batch job that trains a classification model.

Usage:
  $PROGNAME
    --campaign_id CAMPAIGN_ID

Example:
  $PROGNAME
    --campaign_id 6

Options:
  --campaign_id
      (required) Id of campaign. Example: "6"
  --dry_run
      (optional) Enter 1 to NOT submit jobs. Default: "0"
  -h|--help
      Print usage and exit.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
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

# The end of the parsing code.
################################################################################

# Import all constants. Assumes this file is in scripst/inference_classification.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../../constants.sh

dir_of_this_file=$(dirname $(readlink -f $0))
template_path="${dir_of_this_file}/template.sbatch"
if [ ! -f "${template_path}" ]; then
    echo "Job template does not exist at '${template_path}'"
    exit 1
fi

# Stem of the batch job (without extension).
mkdir -p "${PROJECT_DIR}/shared/classification/campaign${campaign_id}/batch_jobs"
batch_job_dir="${PROJECT_DIR}/shared/classification/campaign${campaign_id}/batch_jobs"
batch_job_path_stem="${batch_job_dir}/inference_classification"


sed \
    -e "s|CAMPAIGN_ID|$campaign_id|g" \
    -e "s|PROJECT_DIR|${PROJECT_DIR}|g" \
    -e "s|DATABASES_DIR|${DATABASES_DIR}|g" \
    -e "s|ROOT_DIR|${ROOT_DIR}|g" \
    -e "s|CONDA_INIT_SCRIPT|${CONDA_INIT_SCRIPT}|g" \
    -e "s|CONDA_ENV_DIR|${CONDA_ENV_DIR}|g" \
    -e "s|CLASSIFIER_DIR|${CLASSIFIER_DIR}|g" \
    ${template_path} > "${batch_job_path_stem}.sbatch"
status=$?
if [ ${status} -ne 0 ]; then
    echo "Failed to use the template from '${template_path}'"
    exit ${status}
fi

if [ ${dry_run} == "0" ]; then
    sbatch \
        --output="${batch_job_path_stem}.out" \
        --error="${batch_job_path_stem}.err" \
        "${batch_job_path_stem}.sbatch"
else
    echo "Wrote a job file to '${batch_job_path_stem}.sbatch' without submitting it."
fi

IFS=' ' # reset to default value after usage

