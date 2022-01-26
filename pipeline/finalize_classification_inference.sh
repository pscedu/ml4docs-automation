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
     --in_version VERSION
     --out_version REF_VERSION

Example:
  $PROGNAME
     --campaign_id 8
     --in_version 4
     --out_version 5

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version of the original database with detected stamps and pages, 
                 as well as cropped classified database.
  --out_version
      (required) The version of the output non-cropped database.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
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
  echo "Argument 'in_version' is required."
  exit 1
fi
if [ -z "$out_version" ]; then
  echo "Argument 'out_version' is required."
  exit 1
fi

echo "campaign_id:            ${campaign_id}"
echo "in_version:             ${in_version}"
echo "out_version:            ${out_version}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"


in_db_path=$(get_1800x1200_db_path ${campaign_id} "${in_version}")
ref_db_path=$(get_cropped_db_path ${campaign_id} "${out_version}.expanded")
ref_db_decoded_path=$(get_cropped_db_path ${campaign_id} "${out_version}.expanded.decoded")
out_db_path=$(get_1800x1200_db_path ${campaign_id} ${out_version})

echo "Non-classified database is:                       ${in_db_path}"
echo "Raw predictions (with name_id) in cropped db is:  ${ref_db_path}"
echo "Decoded predictions in cropped db will be:        ${ref_db_decoded_path}"
echo "Classified database will be:                      ${out_db_path}"

ls ${in_db_path}
ls ${ref_db_path}
ls "${ref_db_path}.json"

shuffler_bin=${SHUFFLER_DIR}/shuffler.py

# Decode from name_id to name.
${shuffler_bin} \
  -i ${ref_db_path} \
  -o ${ref_db_decoded_path} \
  decodeStampPredictions --encoding_json "${ref_db_path}.json"

# Populate predicted names from ref_db_path.
${shuffler_bin} \
  -i ${in_db_path} \
  -o ${out_db_path} \
  --rootdir ${ROOT_DIR} \
  syncObjectsDataWithDb --ref_db_file ${ref_db_decoded_path} --cols "name" "score" \| \
  writeMedia \
    --media "video" \
    --image_path "${out_db_path}.avi" \
    --with_objects \
    --with_imageid \
    --overwrite

# Move 
sqlite3 ${out_db_path} "INSERT INTO properties(objectid,key,value) SELECT objectid,'classification_score',score FROM objects WHERE name != 'page' AND score > 0"

echo "Done."