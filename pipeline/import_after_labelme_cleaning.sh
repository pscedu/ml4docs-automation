#!/bin/bash

set -x
set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Parses labelme annotations after tile-based cleaning.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --version OUT_VERSION
     --subversion SUBVERSION

Example:
  $PROGNAME
     --campaign_id 7
     --version 5
     --subversion 1

Options:
  --campaign_id
      (required) The campaign id.
  --version
      (required) The version suffix of the output database.
  --subversion
      (required) The cleaning iteration id.
  --up_to_now
      (optional) 0 or 1. If 1, will export all available data for cleaning.
      If 0, will export only campaign_id. Default is 0. 
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "version"
    "subversion"
    "up_to_now"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
up_to_now=0

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
        --version)
            version=$2
            shift 2
            ;;
        --subversion)
            subversion=$2
            shift 2
            ;;
        --up_to_now)
            up_to_now=$2
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
if [ -z "$version" ]; then
  echo "Argument 'version' is required."
  exit 1
fi
if [ -z "$subversion" ]; then
  echo "Argument 'subversion' is required."
  exit 1
fi

echo "campaign_id:  ${campaign_id}"
echo "version:      ${version}"
echo "subversion:   ${subversion}"
echo "up_to_now:    ${up_to_now}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

shuffler_bin=${SHUFFLER_DIR}/shuffler.py

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_ENV_DIR}/shuffler
echo "Conda environment is activated: '${CONDA_ENV_DIR}/shuffler'"

# Folder with temporary images.
folder="cleaning-v${version}.${subversion}"

prev_subversion=$((${subversion}-1))

if [ ${up_to_now} -eq 0 ]; then

  # Created by pipeline/export_to_labelme_cleaning.sh before the first cleaning.
  in_6Kx4K_db_path=$(get_6Kx4K_db_path ${campaign_id} ${version}.${prev_subversion})
  out_6Kx4K_db_path=$(get_6Kx4K_db_path ${campaign_id} ${version}.${subversion})

  ${dir_of_this_file}/../scripts/collages_for_cleaning/import.sh \
    --campaign_id ${campaign_id} \
    --dirty_db_path ${in_6Kx4K_db_path} \
    --clean_db_path ${out_6Kx4K_db_path} \
    --dirty_folder "${folder}" \
    --clean_folder "${folder}-labeled"

  # TODO: replace INT to FLOAT in bboxes in Shuffler.
  # Uncomment below if you know rectangle positions didn't change.
  # ${shuffler_bin} -i ${out_6Kx4K_db_path} -o ${out_6Kx4K_db_path} \
  #   syncObjectsDataWithDb --ref_db_file ${in_6Kx4K_db_path} --cols x1 y1 width height

  ## Make the database of 6Kx4K up to now.

  out_6Kx4K_uptonow_db_path=$(get_6Kx4K_uptonow_db_path ${campaign_id} ${version}.${subversion})
  previous_campaign_id=$((campaign_id-1))

  # 6Kx4K all campaigns.
  echo "Creating database: ${out_6Kx4K_uptonow_db_path}"
  ${shuffler_bin} \
    -i ${out_6Kx4K_db_path} \
    -o ${out_6Kx4K_uptonow_db_path} \
    addDb --db_file $(get_6Kx4K_uptonow_db_path ${previous_campaign_id} "latest")

  # Make 1800x1200 this campaign.
  out_1800x1200_db_path=$(get_1800x1200_db_path ${campaign_id} ${version}.${subversion})
  echo "Creating database: ${out_1800x1200_db_path}"
  ${shuffler_bin} \
    -i ${out_6Kx4K_db_path} \
    -o ${out_1800x1200_db_path} \
    --rootdir "${ROOT_DIR}" \
    moveMedia --image_path "1800x1200" --level 2 --adjust_size

  # Make 1800x1200 all campaigns.
  out_1800x1200_uptonow_db_path=$(get_1800x1200_uptonow_db_path ${campaign_id} ${version}.${subversion})
  echo "Creating database: ${out_1800x1200_uptonow_db_path}"
  ${shuffler_bin} \
    -i ${out_1800x1200_uptonow_db_path} \
    -o $(get_1800x1200_uptonow_db_path ${campaign_id} ${version}.${subversion}) \
    addDb --db_file $(get_1800x1200_uptonow_db_path ${previous_campaign_id} "latest")

  # Make a video of this campaign.
  ${shuffler_bin} -i ${out_1800x1200_db_path} --rootdir ${ROOT_DIR} \
    writeMedia \
      --media "video" \
      --image_path ${DATABASES_DIR}/campaign${campaign_id}/visualization/$(basename ${out_1800x1200_db_path}).avi \
      --with_objects \
      --with_imageid \
      --overwrite
  echo "Made a video at 'visualization/$(basename ${out_1800x1200_db_path}).avi'."

else 

  # Created by pipeline/export_to_labelme_cleaning.sh before the first cleaning.
  in_6Kx4K_uptonow_db_path=$(get_6Kx4K_uptonow_db_path ${campaign_id} ${version}.${prev_subversion})
  out_6Kx4K_uptonow_db_path=$(get_6Kx4K_uptonow_db_path ${campaign_id} ${version}.${subversion})

  ${dir_of_this_file}/../scripts/collages_for_cleaning/import.sh \
    --campaign_id ${campaign_id} \
    --dirty_db_path ${in_6Kx4K_uptonow_db_path} \
    --clean_db_path ${out_6Kx4K_uptonow_db_path} \
    --dirty_folder "${folder}" \
    --clean_folder "${folder}-labeled"
  
  # Make 1800x1200 all campaigns.
  out_1800x1200_uptonow_db_path=$(get_1800x1200_uptonow_db_path ${campaign_id} ${version}.${subversion})
  echo "Creating database: ${out_1800x1200_uptonow_db_path}"
  ${shuffler_bin} \
    -i ${out_6Kx4K_uptonow_db_path} \
    -o ${out_1800x1200_uptonow_db_path} \
    --rootdir "${ROOT_DIR}" \
    moveMedia --image_path "1800x1200" --level 2 --adjust_size

  # TODO: replace INT to FLOAT in bboxes in Shuffler.
  # Uncomment below if you know rectangle positions didn't change.
  # ${shuffler_bin} -i ${out_6Kx4K_uptonow_db_path} -o ${out_6Kx4K_uptonow_db_path} \
  #   syncObjectsDataWithDb --ref_db_file ${in_6Kx4K_uptonow_db_path} --cols x1 y1 width height

  # Make a video of all campaigns.
  ${shuffler_bin} -i ${out_1800x1200_uptonow_db_path} --rootdir ${ROOT_DIR} \
    writeMedia \
      --media "video" \
      --image_path ${DATABASES_DIR}/campaign${campaign_id}/visualization/$(basename ${out_1800x1200_uptonow_db_path}).avi \
      --with_objects \
      --with_imageid \
      --overwrite
  echo "Made a video at 'visualization/$(basename ${out_1800x1200_uptonow_db_path}).avi'."

fi

## Apply custom rules.

# TODO: add custom rules on "out_6Kx4K_db_path" and "out_6Kx4K_uptonow_db_path"
# SQL="
#   UPDATE objects SET name='kabushikikaisha' WHERE name='kabukishigaisha';
#   UPDATE objects SET name='goumeikaisha' WHERE name='goumeigaisha';
#   UPDATE objects SET name='kenkyusho' WHERE name='kenkyujo';
#   UPDATE objects SET name='seisakusho' WHERE name='seisakujo';
# "
# sqlite3 ${out_6Kx4K_db_path} "${SQL}"
# sqlite3 ${out_6Kx4K_uptonow_db_path} "${SQL}"

echo "Done."
