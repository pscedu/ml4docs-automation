#!/bin/bash

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
     --in_version IN_VERSION
     --out_version OUT_VERSION
     --up_to_now {0,1}

Example:
  $PROGNAME
     --campaign_id 7
     --in_version 5
     --out_version 1

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version suffix of the input database.
  --out_version
      (required) The version suffix of the output database.
  --up_to_now
      (optional) 0 or 1. If 1, will import data from all campaigns.
      If 0, will import only campaign_id. Default is 0.
  --num_images_for_video
      (optional) How many random images to write to the video.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "out_version"
    "up_to_now"
    "num_images_for_video"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
up_to_now=0
num_images_for_video=100

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
        --num_images_for_video)
            num_images_for_video=$2
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
echo "num_images_for_video: ${num_images_for_video}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh
source ${dir_of_this_file}/../path_generator.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"

# Folder with temporary images.
folder="cleaning-v${in_version}"

# If ONLY this campaign was cleaned.
if [ ${up_to_now} -eq 0 ]; then

  # Created by pipeline/export_to_labelme_cleaning.sh before the first cleaning.
  in_6Kx4K_db_path=$(get_6Kx4K_db_path ${campaign_id} ${in_version})
  out_6Kx4K_db_path=$(get_6Kx4K_db_path ${campaign_id} ${out_version})

  ${dir_of_this_file}/../scripts/collages_for_cleaning/import.sh \
    --campaign_id ${campaign_id} \
    --dirty_db_path "${in_6Kx4K_db_path}" \
    --clean_db_path "${out_6Kx4K_db_path}" \
    --dirty_folder "${folder}" \
    --clean_folder "${folder}-labeled"

  # Uncomment below if you know rectangle positions didn't change.
  # python -m shuffler -i ${out_6Kx4K_db_path} -o ${out_6Kx4K_db_path} \
  #   syncObjectsDataWithDb --ref_db_file ${in_6Kx4K_db_path} --cols x1 y1 width height

  ## Make the database of 6Kx4K up to now.

  out_6Kx4K_uptonow_db_path=$(get_6Kx4K_uptonow_db_path ${campaign_id} ${out_version})
  previous_campaign_id=$((campaign_id-1))

  # 6Kx4K all campaigns.
  echo "Creating database: ${out_6Kx4K_uptonow_db_path}"
  python -m shuffler \
    -i ${out_6Kx4K_db_path} \
    -o ${out_6Kx4K_uptonow_db_path} \
    addDb --db_file $(get_6Kx4K_uptonow_db_path ${previous_campaign_id} "latest")

  # Make 1800x1200 this campaign.
  out_1800x1200_db_path=$(get_1800x1200_db_path ${campaign_id} ${out_version})
  echo "Creating database: ${out_1800x1200_db_path}"
  python -m shuffler \
    -i ${out_6Kx4K_db_path} \
    -o ${out_1800x1200_db_path} \
    --rootdir "${ROOT_DIR}" \
    moveMedia --image_path "1800x1200" --level 2 \| \
    resizeAnnotations

  # Make 1800x1200 all campaigns.
  out_1800x1200_uptonow_db_path=$(get_1800x1200_uptonow_db_path ${campaign_id} ${out_version})
  echo "Creating database: ${out_1800x1200_uptonow_db_path}"
  python -m shuffler \
    -i ${out_1800x1200_db_path} \
    -o ${out_1800x1200_uptonow_db_path} \
    addDb --db_file $(get_1800x1200_uptonow_db_path ${previous_campaign_id} "latest")

  # Make a video of this campaign.
  python -m shuffler -i ${out_1800x1200_db_path} --rootdir ${ROOT_DIR} \
    randomNImages -n ${num_images_for_video} \| \
    writeMedia \
      --media "video" \
      --image_path "${out_1800x1200_db_path}.avi" \
      --with_objects \
      --with_imageid \
      --overwrite
  echo "Made a video at ${out_1800x1200_db_path}.avi"

  log_db_version ${campaign_id} ${out_version} "A cleaning round have completed on the latest campaign."

# If ALL campaigns were cleaned.
else 

  # Created by pipeline/export_to_labelme_cleaning.sh before the first cleaning.
  in_6Kx4K_uptonow_db_path=$(get_6Kx4K_uptonow_db_path ${campaign_id} ${in_version})
  out_6Kx4K_uptonow_db_path=$(get_6Kx4K_uptonow_db_path ${campaign_id} ${out_version})

  ${dir_of_this_file}/../scripts/collages_for_cleaning/import.sh \
    --campaign_id ${campaign_id} \
    --dirty_db_path ${in_6Kx4K_uptonow_db_path} \
    --clean_db_path ${out_6Kx4K_uptonow_db_path} \
    --dirty_folder "${folder}" \
    --clean_folder "${folder}-labeled"
  
  # Make 1800x1200 all campaigns.
  out_1800x1200_uptonow_db_path=$(get_1800x1200_uptonow_db_path ${campaign_id} ${out_version})
  echo "Creating database: ${out_1800x1200_uptonow_db_path}"
  python -m shuffler \
    -i ${out_6Kx4K_uptonow_db_path} \
    -o ${out_1800x1200_uptonow_db_path} \
    --rootdir "${ROOT_DIR}" \
    moveMedia --image_path "1800x1200" --level 2 \| \
    resizeAnnotations

  # TODO: replace INT to FLOAT in bboxes in Shuffler.
  # Uncomment below if you know rectangle positions didn't change.
  # python -m shuffler -i ${out_6Kx4K_uptonow_db_path} -o ${out_6Kx4K_uptonow_db_path} \
  #   syncObjectsDataWithDb --ref_db_file ${in_6Kx4K_uptonow_db_path} --cols x1 y1 width height

  # Make a video of all campaigns.
  python -m shuffler -i ${out_1800x1200_uptonow_db_path} --rootdir ${ROOT_DIR} \
    randomNImages -n ${num_images_for_video} \| \
    writeMedia \
      --media "video" \
      --image_path "${out_1800x1200_uptonow_db_path}.avi" \
      --with_objects \
      --with_imageid \
      --overwrite
  echo "Made a video at ${out_1800x1200_uptonow_db_path}.avi"

  log_db_version ${campaign_id} ${out_version} "A cleaning round have completed on all campaigns."
fi

echo "Done."
