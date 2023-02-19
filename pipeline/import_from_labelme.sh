#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Parses labelme annotations (NOT tile-based cleaning).

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version IN_VERSION
     --prev_version PREV_VERSION
     --out_version OUT_VERSION

Example:
  $PROGNAME
     --campaign_id 9
     --in_version 7

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version that was exported to Labelme (used to evaluate).
  --prev_version
      (required) The version BEFORE the export to Labelme. Default is in_version - 1.
  --out_version
      (optional) The version suffix of the output database. Default is in_version + 1.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "prev_version"
    "in_version"
    "out_version"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# No defaults.

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
        --prev_version)
            prev_version=$2
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
  echo "Argument 'out_version' is required."
  exit 1
fi
if [ -z "$prev_version" ]; then
  prev_version=$((${in_version} - 1))
  echo "Argument 'prev_version' is not provided. Will use ${prev_version}."
fi
if [ -z "$out_version" ]; then
  out_version=$((${in_version} + 1))
  echo "Argument 'out_version' is not provided. Will use ${out_version}."
fi
previous_campaign_id=$((campaign_id-1))

echo "campaign_id:           ${campaign_id}"
echo "previous_campaign_id:  ${previous_campaign_id}"
echo "in_version:            ${in_version}"
echo "prev_version:          ${prev_version}"
echo "out_version:           ${out_version}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"

in_db_1800x1200_uptoprevious_path=$(get_1800x1200_uptonow_db_path ${previous_campaign_id} "latest")
in_db_6Kx4K_uptoprevious_path=$(get_6Kx4K_uptonow_db_path ${previous_campaign_id} "latest")
in_db_1800x1200_path=$(get_1800x1200_db_path ${campaign_id} ${in_version})
prev_db_1800x1200_path=$(get_1800x1200_db_path ${campaign_id} ${prev_version})
out_db_1800x1200_path=$(get_1800x1200_db_path ${campaign_id} ${out_version})
out_db_6Kx4K_path=$(get_6Kx4K_db_path ${campaign_id} ${out_version})
out_db_1800x1200_uptonow_path=$(get_1800x1200_uptonow_db_path ${campaign_id} ${out_version})
out_db_6Kx4K_uptonow_path=$(get_6Kx4K_uptonow_db_path ${campaign_id} ${out_version})

# If this script was already run before, the output db exists, and Shuffler will raise an exception.
rm -f ${out_db_1800x1200_path} ${out_db_6Kx4K_path} ${out_db_1800x1200_uptonow_path} ${out_db_6Kx4K_uptonow_path}

labelme_rootdir="${LABELME_DIR}/campaign${campaign_id}/initial-labeled"

python -m shuffler \
  --logging 30 \
  --rootdir ${labelme_rootdir} \
  -o ${out_db_1800x1200_path} \
  importLabelme \
    --images_dir "${labelme_rootdir}/Images" \
    --annotations_dir "${labelme_rootdir}/Annotations" \
    --ref_db_file ${in_db_1800x1200_path} \| \
  moveRootdir \
    --new_rootdir ${ROOT_DIR}

sqlite3 ${out_db_1800x1200_path} "
  UPDATE objects SET name = CAST(name AS TEXT);
  UPDATE objects SET name = REPLACE(name, '-', '');
  UPDATE objects SET name = REPLACE(name, '.', '');
  UPDATE objects SET name='??' WHERE name == 'unclear';
"

python -m shuffler \
  --rootdir ${ROOT_DIR} \
  --logging 30 \
  -i ${out_db_1800x1200_path} \
  -o ${out_db_1800x1200_path} \
  extractNumberIntoProperty --property "number" \| \
  syncObjectidsWithDb --ref_db_file ${prev_db_1800x1200_path}

# Add the "campaign" property.
sqlite3 ${out_db_1800x1200_path} "
  UPDATE images SET name='${campaign_id}';
  INSERT INTO properties(objectid,key,value) SELECT objectid,'campaign',${campaign_id} FROM objects
"

# Get the same db but with big images.
python -m shuffler \
  -i ${out_db_1800x1200_path} -o ${out_db_6Kx4K_path} --rootdir ${ROOT_DIR} --logging 30 \
  moveMedia --image_path "original_dataset" --level 2 --adjust_size

# Merge 1800x1200 with the previous campaign.
echo "Merging 1800x1200 with the previous campaign..."
python -m shuffler \
  -i ${out_db_1800x1200_path} \
  -o ${out_db_1800x1200_uptonow_path} \
  addDb --db_file ${in_db_1800x1200_uptoprevious_path}

# Merge 6Kx4K with the previous campaign.
echo "Merging 6Kx4K with the previous campaign..."
python -m shuffler \
  -i ${out_db_6Kx4K_path} \
  -o ${out_db_6Kx4K_uptonow_path} \
  addDb --db_file ${in_db_6Kx4K_uptoprevious_path}

# Can't be combined with the previous step, otherwise images will be different in db.
python -m shuffler \
  -i ${out_db_1800x1200_path} \
  --rootdir ${ROOT_DIR} \
  writeMedia \
    --media "video" \
    --image_path "${out_db_1800x1200_path}.avi" \
    --with_objects \
    --with_imageid \
    --overwrite

log_db_version ${campaign_id} ${out_version} "Imported from labelme."
echo "Done."
