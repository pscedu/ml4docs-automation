#!/bin/bash

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
This scripts submits a job to make tiles out of a db for cleaning.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_NAME
     --dirty_db_name DB_NAME
     --dirty_folder OUTPUT_FOLDER
     --project_dir PROJECT_DIR

Example:
  $PROGNAME
     --campaign_id 5 \
     --dirty_db_name "campaign3to5-6Kx4K.v5.db" \
     --dirty_folder "cleaning-v5-campaign3to5"

Options:
  --campaign_id
      (required) The campaign id where all the files reside
  --dirty_db_name
      (required) Input database.
  --dirty_folder
      (required) All intermediate and final results will have this name.
  --project_dir
      (optional) The directory of the whole project on bridges/bridges2.
  --dry_run
      (optional) Enter 1 to NOT submit jobs. Default: "0"
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "dirty_db_name"
    "dirty_folder"
    "project_dir"
    "dry_run"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
project_dir="/ocean/projects/hum180001p"
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
        --dirty_db_name)
            dirty_db_name=$2
            shift 2
            ;;
        --dirty_folder)
            dirty_folder=$2
            shift 2
            ;;
        --project_dir)
            project_dir=$2
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
if [ -z "$dirty_db_name" ]; then
  echo "Argument 'dirty_db_name' is required."
  exit 1
fi
if [ -z "$dirty_folder" ]; then
  echo "Argument 'dirty_folder' is required."
  exit 1
fi

# The end of the parsing code.
################################################################################

script_dir=$(dirname "$0")
template_path="${script_dir}/template.sbatch"
if [ ! -f "${template_path}" ]; then
    echo "Job template does not exist at '${template_path}'"
    exit 1
fi

batch_job_dir="${project_dir}/etoropov/campaign${campaign_id}/batch_jobs"

sed \
    -e "s|PROJECT_DIR|${project_dir}|g" \
    -e "s|CAMPAIGN_ID|$campaign_id|g" \
    -e "s|DB_NAME|${dirty_db_name}|g" \
    -e "s|FOLDER|${dirty_folder}|g" \
    ${template_path} > "${batch_job_dir}/${dirty_folder}.sbatch"
status=$?
if [ ${status} -ne 0 ]; then
    echo "Failed to use the template from '${template_path}'"
    exit ${status}
fi

if [ ${dry_run} == "0" ]; then
    sbatch \
        --output="${batch_job_dir}/${dirty_folder}.out" \
        --error="${batch_job_dir}/${dirty_folder}.err" \
        "${batch_job_dir}/${dirty_folder}.sbatch"
else
    echo "Wrote ready job to '${batch_job_dir}/${dirty_folder}.sbatch'"
fi

IFS=' ' # reset to default value after usage

