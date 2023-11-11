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
     --up_to_now {0,1}
     --folder FOLDER
     --stamp_threshold STAMP_THRESHOLD

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
  --up_to_now
      (optional) 0 or 1. If 1, will export all available data for cleaning.
      If 0, will export only campaign_id. Default is 0.
  --folder
      (optional) Folder in the labelme directory. Default: "initial".
  --stamp_threshold
      (optional) stamp classification threshold.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "out_version"
    "up_to_now"
    "folder"
    "stamp_threshold"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
up_to_now=0
folder="initial"
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
        --up_to_now)
            up_to_now=$2
            shift 2
            ;;
        --folder)
            folder=$2
            shift 2
            ;;
        --stamp_threshold)
            stamp_threshold=$2
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
echo "up_to_now:            ${up_to_now}"
echo "folder:               ${folder}"
echo "stamp_threshold:      ${stamp_threshold}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh
source ${dir_of_this_file}/../path_generator.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"

if [ ${up_to_now} -eq 0 ]; then
  in_db_path=$(get_1800x1200_db_path ${campaign_id} ${in_version})
  out_db_path=$(get_1800x1200_db_path ${campaign_id} ${out_version})
else
  in_db_path=$(get_1800x1200_uptonow_db_path ${campaign_id} ${in_version})
  out_db_path=$(get_1800x1200_uptonow_db_path ${campaign_id} ${out_version})
fi

labelme_rootdir="${LABELME_DIR}/campaign${campaign_id}/${folder}"

python -m shuffler --rootdir ${ROOT_DIR} -i ${in_db_path} -o ${out_db_path} \
  filterObjectsSQL \
    --delete \
    --sql "SELECT objectid FROM objects WHERE name = 'stamp' AND score < ${stamp_threshold}" \| \
  moveRootdir \
    --new_rootdir ${labelme_rootdir}

# Can't combine with the previous step because rootdir has changed.
echo "Exporting to '${labelme_rootdir}'"
python -m shuffler \
  -i ${out_db_path} \
  -o ${out_db_path} \
  --rootdir ${labelme_rootdir} \
  --logging 30 \
  exportLabelme \
    --images_dir "${labelme_rootdir}/Images" \
    --annotations_dir "${labelme_rootdir}/Annotations" \
    --username ${LABELME_USER} \
    --folder ${folder} \
    --dirtree_level_for_name 2 \
    --fix_invalid_image_names \
    --overwrite

# Can't be combined with the previous step, otherwise images will be different in db.
python -m shuffler \
  -i ${out_db_path} \
  --rootdir ${labelme_rootdir} \
  writeMedia \
    --media "video" \
    --image_path "${out_db_path}.avi" \
    --with_objects \
    --with_imageid \
    --overwrite

log_db_version ${campaign_id} ${out_version} \
    "Low-confidence stamp classifications are discarded, exported to labelme."
echo "Done."
