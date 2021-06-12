#!/bin/bash

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
This script starts a batch job that crops stamp objects (not pages) from a database.

Usage:
  $PROGNAME
     --project_dir PROJECT_DIR
     --root_dir ROOT_DIR
     --campaign_id CAMPAIGN_ID
     --db_stem DB_STEM
     --size SIZE

Example:
  $PROGNAME
     --campaign_id 6
     --db_stem campaign3to6-6Kx4K.v7
     --size 260

Options:
  --campaign_id
      (required) Id of campaign. Example: "5"
  --db_stem
      (required) Name stem (no extension) of the database to crop. Example: "campaign3to6-6Kx4K.v7"
  --project_dir
      (optional) Defaults to /ocean/projects/hum180001p
  --root_dir
      (optional) Defaults to /ocean/projects/hum180001p/shared/data
  --size
      (optional) If specified, resize to this size, otherwise, keep the original size.
  --dry_run
      (optional) Enter 1 to NOT submit jobs. Default: "0"
  -h|--help
      Print usage and exit.
EO
}

ARGUMENT_LIST=(
    "project_dir"
    "root_dir"
    "campaign_id"
    "db_stem"
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
project_dir="/ocean/projects/hum180001p"
root_dir="/ocean/projects/hum180001p/shared/data"
size=""
dry_run=0

eval set --$opts

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --project_dir)
            project_dir=$2
            shift 2
            ;;
        --root_dir)
            root_dir=$2
            shift 2
            ;;
        --campaign_id)
            campaign_id=$2
            shift 2
            ;;
        --db_stem)
            db_stem=$2
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
if [ -z "$db_stem" ]; then
  echo "Argument 'db_stem' is required."
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

# Stem of the batch job (without extension).
batch_job_dir="${project_dir}/etoropov/campaign${campaign_id}/batch_jobs"
batch_job_path_stem="${batch_job_dir}/crop-objects-${db_stem}"

sed \
    -e "s|PROJECT_DIR|${project_dir}|g" \
    -e "s|CAMPAIGN_ID|$campaign_id|g" \
    -e "s|DB_STEM|${db_stem}|g" \
    -e "s|SIZE|${size}|g" \
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
    echo "Wrote ready job to '${batch_job_path_stem}.sbatch'"
fi

IFS=' ' # reset to default value after usage

