#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Perform the necessary back-imports from cropped inferenced database to
the 6Kx4K image database and to the 1800x1200 image database. Visualize.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --ref_version INT
     --in_version INT
     --out_version INT
     --model_campaign_id MODEL_CAMPAIGN_ID
     --set_id SET_ID
     --run_id RUN_ID

Example:
  $PROGNAME
     --campaign_id 8
     --ref_version 3
     --in_version 4
     --out_version 5
     --model_campaign_id 7
     --run_id 0

Options:
  --campaign_id
      (required) The campaign id.
  --ref_version
      (required) The cropped version before classification.
  --in_version
      (required) The cropped classified version.
  --out_version
      (required) The new version to create.
  --model_campaign_id
      (optional) Pick which campaign used for detection. Default: campaign_id-1.
  --set_id
      (optional) Which set of models to use for the inference.
  --run_id
      (Required) Run id of the model.
  --num_images_for_video
      (optional) How many random images to write to the video.

  CAUTION: --ref_version and --in_version should match the ones used in
           start_classification_inference.sh.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "ref_version"
    "in_version"
    "out_version"
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
set_id="expand0.5.size260"
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
        --ref_version)
            ref_version=$2
            shift 2
            ;;
        --out_version)
            out_version=$2
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
if [ -z "$ref_version" ]; then
  echo "Argument 'ref_version' is required."
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
if [ -z "$model_campaign_id" ]; then
  model_campaign_id=$((campaign_id-1))
  echo "Automatically setting model_campaign_id to ${model_campaign_id}."
fi
if [ -z "$run_id" ]; then
  echo "Argument 'run_id' is required."
  exit 1
fi

echo "campaign_id:            ${campaign_id}"
echo "ref_version:            ${ref_version}"
echo "in_version:             ${in_version}"
echo "out_version:            ${out_version}"
echo "model_campaign_id:      ${model_campaign_id}"
echo "set_id:                 ${set_id}"
echo "run_id:                 ${run_id}"
echo "num_images_for_video:   ${num_images_for_video}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh
source ${dir_of_this_file}/../path_generator.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"


# Original non-cropped version.
in_db_path=$(get_1800x1200_db_path ${campaign_id} "${ref_version}")
# Classified cropped version.
ref_db_path=$(get_classified_cropped_db_path ${campaign_id} ${in_version} ${model_campaign_id} ${set_id} ${run_id})
# The output non-cropped version.
out_db_path=$(get_1800x1200_db_path ${campaign_id} ${out_version})

echo "Non-classified database is:    ${ref_db_path}"
echo "Predictions in cropped db is:  ${in_db_path}"
echo "Classified database will be:   ${out_db_path}"

ls ${ref_db_path}
ls ${in_db_path}

# Populate predicted names from ref_db_path.
python -m shuffler \
  -i ${in_db_path} \
  -o ${out_db_path} \
  syncObjectsDataWithDb --ref_db_file ${ref_db_path} --cols "name" "score"

# Can't be combined with the previous step, otherwise images will be different in db.
python -m shuffler \
  -i ${out_db_path} \
  --rootdir ${ROOT_DIR} \
  randomNImages -n ${num_images_for_video} \| \
  writeMedia \
    --media "video" \
    --image_path "${out_db_path}.avi" \
    --with_objects \
    --with_imageid \
    --overwrite

# Copy classification scores to properties.
sqlite3 ${out_db_path} "INSERT INTO properties(objectid,key,value) SELECT objectid,'classification_score',score FROM objects WHERE name != 'page' AND score > 0"

# NOTE: A new version does not appear. ${out_version} already exists and means
#       the stamps are classifed. It is introduced by start_classification_inference.sh
log_db_version ${campaign_id} ${out_version} \
  "Imported cropped classified stamps by finalize_classification_inference."
echo "Done."
