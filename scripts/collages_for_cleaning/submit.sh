#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
This scripts submits a job to make tiles out of a db for cleaning.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_NAME
     --in_db_name DB_NAME
     --folder OUTPUT_FOLDER

Example:
  $PROGNAME
     --campaign_id 5
     --in_db_name "campaign3to5-6Kx4K.v5.db"
     --folder "cleaning-v5-campaign3to5"

Options:
  --campaign_id
      (required) The campaign id where all the files reside.
  --in_db_name
      (required) Name of the input database.
  --folder
      (required) All intermediate and final results will have this name.
  --dry_run
      (optional) Enter 1 to NOT submit jobs. Default: "0"
  -h|--help
      Print usage and exit.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_db_name"
    "folder"
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
        --in_db_name)
            in_db_name=$2
            shift 2
            ;;
        --folder)
            folder=$2
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
if [ -z "$in_db_name" ]; then
  echo "Argument 'in_db_name' is required."
  exit 1
fi
if [ -z "$folder" ]; then
  echo "Argument 'folder' is required."
  exit 1
fi

# The end of the parsing code.
################################################################################

dir_of_this_file=$(dirname $(readlink -f $0))
template_path="${dir_of_this_file}/template.sbatch"
if [ ! -f "${template_path}" ]; then
    echo "Job template does not exist at '${template_path}'"
    exit 1
fi

batch_job_dir="${DATABASES_DIR}/campaign${campaign_id}/batch_jobs"
batch_job_path_stem="${batch_job_dir}/crop_collage_${folder}_$(date +%Y-%m-%d_%H-%M-%S)"

sed \
    -e "s|CAMPAIGN_ID|$campaign_id|g" \
    -e "s|IN_DB_NAME|${in_db_name}|g" \
    -e "s|FOLDER|${folder}|g" \
    -e "s|SHUFFLER_DIR|$SHUFFLER_DIR|g" \
    -e "s|CONDA_INIT_SCRIPT|${CONDA_INIT_SCRIPT}|g" \
    -e "s|CONDA_ENV_DIR|${CONDA_ENV_DIR}|g" \
    -e "s|DATABASES_DIR|${DATABASES_DIR}|g" \
    -e "s|ROOT_DIR|${ROOT_DIR}|g" \
    -e "s|LABELME_USER|${LABELME_USER}|g" \
    -e "s|LABELME_DIR|${LABELME_DIR}|g" \
    ${template_path} > "${batch_job_path_stem}.sbatch"
status=$?
if [ ${status} -ne 0 ]; then
    echo "Failed to use the template from '${template_path}'"
    exit ${status}
fi

if [ ${dry_run} == "0" ]; then
    sbatch -A ${ACCOUNT} \
        --output="${batch_job_path_stem}.out" \
        --error="${batch_job_path_stem}.err" \
        "${batch_job_path_stem}.sbatch"
else
    echo "Wrote ready job to '${batch_job_path_stem}.sbatch'"
fi

IFS=' ' # reset to default value after usage

