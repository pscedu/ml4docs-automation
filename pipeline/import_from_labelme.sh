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
     --out_version OUT_VERSION

Example:
  $PROGNAME
     --campaign_id 8
     --out_version 7

Options:
  --campaign_id
      (required) The campaign id.
  --out_version
      (required) The version suffix of the output database.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
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
if [ -z "$out_version" ]; then
  echo "Argument 'out_version' is required."
  exit 1
fi
previous_campaign_id=$((campaign_id-1))

echo "campaign_id:           ${campaign_id}"
echo "previous_campaign_id:  ${previous_campaign_id}"
echo "out_version:           ${out_version}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"

shuffler_bin=${SHUFFLER_DIR}/shuffler.py

in_db_1800x1200_uptoprevious_path=$(get_1800x1200_uptonow_db_path ${previous_campaign_id} "latest")
in_db_6Kx4K_uptoprevious_path=$(get_6Kx4K_uptonow_db_path ${previous_campaign_id} "latest")
out_db_1800x1200_path=$(get_1800x1200_db_path ${campaign_id} ${out_version})
out_db_6Kx4K_path=$(get_6Kx4K_db_path ${campaign_id} ${out_version})
out_db_1800x1200_uptonow_path=$(get_1800x1200_uptonow_db_path ${campaign_id} ${out_version})
out_db_6Kx4K_uptonow_path=$(get_6Kx4K_uptonow_db_path ${campaign_id} ${out_version})

# If this script was already run before, the output db exists, and Shuffler will raise an exception.
rm -f ${out_db_1800x1200_path} ${out_db_6Kx4K_path} ${out_db_1800x1200_uptonow_path} ${out_db_6Kx4K_uptonow_path}

${shuffler_bin} \
  --logging 30 \
  --rootdir ${ROOT_DIR} \
  -o ${out_db_1800x1200_path} \
  importLabelme \
    --images_dir "${LABELME_DIR}/campaign${campaign_id}/initial-labeled/Images" \
    --annotations_dir "${LABELME_DIR}/campaign${campaign_id}/initial-labeled/Annotations" \| \
  moveToRajaFolderStructure \
    --target_dir "1800x1200/" \
    --rootdir_for_validation "${ROOT_DIR}" \
    --subfolder_list_path "${PROJECT_DIR}/shared/data/subfolder_list.txt"

sqlite3 ${out_db_1800x1200_path} "
  UPDATE objects SET name = CAST(name AS TEXT); 
  UPDATE objects SET name = REPLACE(name, '-', '');
  UPDATE objects SET name = REPLACE(name, '.', '');
  UPDATE objects SET name='??' WHERE name == 'unclear';
"

${shuffler_bin} \
  -i ${out_db_1800x1200_path} -o ${out_db_1800x1200_path} --logging 30 \
  extractNumberIntoProperty --property "number" \| \
  filterObjectsInsideCertainObjects \
    --where_shadowing_objects "SELECT objectid WHERE name IN ('page_rb','page_lb', 'pagerb','pagelb')"

# Add the "campaign" property.
sqlite3 ${out_db_1800x1200_path} \
  "INSERT INTO properties(objectid,key,value) SELECT objectid,'campaign',${campaign_id} FROM objects"

# Get the same db but with big images.
${shuffler_bin} \
  -i ${out_db_1800x1200_path} -o ${out_db_6Kx4K_path} --rootdir ${ROOT_DIR} --logging 30 \
  moveMedia --image_path "original_dataset" --level 2 --adjust_size \| \
  filterImages

# Merge 1800x1200 with the previous campaign.
echo "Merging 1800x1200 with the previous campaign..."
${shuffler_bin} \
  -i ${out_db_1800x1200_path} \
  -o ${out_db_1800x1200_uptonow_path} \
  addDb --db_file ${in_db_1800x1200_uptoprevious_path}

# Merge 6Kx4K with the previous campaign.
echo "Merging 6Kx4K with the previous campaign..."
${shuffler_bin} \
  -i ${out_db_6Kx4K_path} \
  -o ${out_db_6Kx4K_uptonow_path} \
  addDb --db_file ${in_db_6Kx4K_uptoprevious_path}

log_db_version ${campaign_id} ${out_version} "Imported from labelme."
echo "Done."
