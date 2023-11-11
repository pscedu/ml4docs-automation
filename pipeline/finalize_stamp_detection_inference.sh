#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Copy the detected database to the output version and threshold stamp detections.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --out_version OUT_VERSION
     --threshold THRESHOLD
     --model_campaign_id MODEL_CAMPAIGN_ID
     --set_id SET_ID
     --run_id RUN_ID

Example:
  $PROGNAME
     --campaign_id 8
     --out_version 5
     --run_id 0

Options:
  --campaign_id
      (required) The campaign id.
  --out_version
      (required) The version of the output non-cropped database.
  --threshold
      (optional) Detections under the threshold are deleted. Default: 0.2.
  --model_campaign_id
      (optional) Pick which campaign used for detection. Default: campaign_id-1.
  --set_id
      (optional) Set id of the model. Default: "set-stamp-1800x1200".
  --run_id
      (Required) Run id of the model.
  --num_images_for_video
      (optional) How many random images to write to the video.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "out_version"
    "threshold"
    "model_campaign_id"
    "set_id"
    "run_id"
    "num_images_for_video"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
set_id="set-stamp-1800x1200"
threshold=0.2
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
        --out_version)
            out_version=$2
            shift 2
            ;;
        --threshold)
            threshold=$2
            shift 2
            ;;
        --model_campaign_id)
            model_campaign_id=$2
            shift 2
            ;;
        --set_id)
            set_id=$2
            shift 2
            ;;
        --run_id)
            run_id=$2
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
if [ -z "$out_version" ]; then
  echo "Argument 'out_version' is required."
  exit 1
fi
if [ -z "$model_campaign_id" ]; then
  model_campaign_id=$((campaign_id-1))
  echo "Automatically setting model_campaign_id to ${model_campaign_id}."
fi
if [ -z "$run_id" ]; then
  echo "Argument 'run_id' is required."
  exit 1
fi

echo "campaign_id:            ${campaign_id}"
echo "out_version:            ${out_version}"
echo "threshold:              ${threshold}"
echo "set_id:                 ${set_id}"
echo "run_id:                 ${run_id}"
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


in_db_path=$(get_detected_db_path ${campaign_id} ${model_campaign_id} ${set_id} ${run_id})
out_db_path=$(get_1800x1200_db_path ${campaign_id} ${out_version})

ls ${in_db_path}

echo "Number of detections BEFORE filtering:"
sqlite3 ${in_db_path} "SELECT name,COUNT(1) FROM objects GROUP BY name"

python -m shuffler -i ${in_db_path} -o ${out_db_path} \
  filterObjectsSQL --sql "SELECT objectid FROM objects WHERE name = 'stamp' AND score < ${threshold}" --delete \| \
  sql --sql "INSERT INTO properties(objectid,key,value) SELECT objectid,'stamp_detection_score',score FROM objects" \| \
  sql --sql "UPDATE objects SET score = 0"

echo "Number of detections AFTER filtering:"
sqlite3 ${out_db_path} "SELECT name,COUNT(1) FROM objects GROUP BY name"

python -m shuffler -i ${out_db_path} --rootdir ${ROOT_DIR} \
  randomNImages -n ${num_images_for_video} \| \
  writeMedia \
    --media "video" \
    --image_path "${out_db_path}.avi" \
    --with_objects \
    --with_imageid \
    --overwrite

log_db_version ${campaign_id} ${out_version} \
  "Filtered bad stamp detections, save detection scores in proporties."
echo "Done."
