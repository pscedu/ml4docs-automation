#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Filters low-confidence classification and exports to Labelme.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version OUT_VERSION
     --out_version OUT_VERSION
     --stamp_threshold STAMP_THRESHOLD
     --dry_run DRY_RUN

Example:
  $PROGNAME
     --campaign_id 8
     --in_version 5
     --out_version 6

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version suffix of the input database.
  --out_version
      (required) The version suffix of the output database.
  --stamp_threshold
      (optional) stamp classification threshold.
  --dry_run
      (optional) Enter 1 to NOT submit jobs. Default: "0"
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "out_version"
    "stamp_threshold"
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
stamp_threshold=0.5

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
        --out_version)
            out_version=$2
            shift 2
            ;;
        --stamp_threshold)
            stamp_threshold=$2
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
if [ -z "$out_version" ]; then
  echo "Argument 'out_version' is required."
  exit 1
fi

echo "campaign_id:          ${campaign_id}"
echo "in_version:           ${in_version}"
echo "out_version:          ${out_version}"
echo "stamp_threshold:      ${stamp_threshold}"
echo "dry_run:              ${dry_run}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"

shuffler_bin=${SHUFFLER_DIR}/shuffler.py

in_db_path=$(get_1800x1200_db_path ${campaign_id} ${in_version})
out_db_path=$(get_1800x1200_db_path ${campaign_id} ${out_version})

${shuffler_bin} --rootdir ${ROOT_DIR} -i ${in_db_path} -o ${out_db_path} \
  classifyPages \| \
  filterObjectsSQL --sql "SELECT objectid FROM objects WHERE name = 'stamp' AND score < ${stamp_threshold}" \| \
  exportLabelme \
    --images_dir "${LABELME_DIR}/campaign${campaign_id}/initial/Images" \
    --annotations_dir "${LABELME_DIR}/campaign${campaign_id}/initial/Annotations" \
    --username ${LABELME_USER} \
    --folder "initial" \
    --overwrite

# Can't be combined with the previous step, otherwise images will be different in db.
${shuffler_bin} --rootdir ${ROOT_DIR} -i ${out_db_path} \
  writeMedia \
    --media "video" \
    --image_path "${out_db_path}.avi" \
    --with_objects \
    --with_imageid \
    --overwrite

log_db_version ${campaign_id} ${out_version} \
    "Pages are classified, low-confidence stamp classifications are discarded, exported to labelme."
echo "Done."
