#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
This scripts imports tiles after cleaning in Labelme.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --dirty_db_path DIRTY_DB_NAME
     --clean_db_path CLEAN_DB_NAME
     --dirty_folder DIRTY_FOLDER_NAME
     --clean_folder CLEAN_FOLDER_NAME

Example:
  $PROGNAME
     --campaign_id 5
     --dirty_db_path "campaign5-6Kx4K.v5.db"
     --clean_db_path "campaign5-6Kx4K.v6.db"
     --dirty_folder "cleaning1"
     --clean_folder "cleaning1-labeled"

Options:
  --campaign_id
      (required) The campaign id where all the files reside.
  --dirty_db_path
      (required) Input database.".
  --clean_db_path
      (required) Output database.".
  --dirty_folder
      (required) Should have been generated as a database with cropped stamps at:
                 "\${DATABASE_DIR}/campaign/\${campaign_id}/labelme/".
  --clean_folder
      (required) Should have cleaned Labelme Images and Annotations subfolders at:
                 "\${LABELME_DIR}/campaign/\${campaign_id}/".
                 Also should have a database with the same name at:
                 "\${DATABASE_DIR}/campaign/\${campaign_id}/labelme/".
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "dirty_folder"
    "clean_folder"
    "dirty_db_path"
    "clean_db_path"
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
        --dirty_folder)
            dirty_folder=$2
            shift 2
            ;;
        --clean_folder)
            clean_folder=$2
            shift 2
            ;;
        --dirty_db_path)
            dirty_db_path=$2
            shift 2
            ;;
        --clean_db_path)
            clean_db_path=$2
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
if [ -z "$dirty_folder" ]; then
  echo "Argument 'dirty_folder' is required."
  exit 1
fi
if [ -z "$clean_folder" ]; then
  echo "Argument 'clean_folder' is required."
  exit 1
fi
if [ -z "$dirty_db_path" ]; then
  echo "Argument 'dirty_db_path' is required."
  exit 1
fi
if [ -z "$clean_db_path" ]; then
  echo "Argument 'clean_db_path' is required."
  exit 1
fi

# The end of the parsing code.
################################################################################


# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../../constants.sh
source ${dir_of_this_file}/../../path_generator.sh

cd ${DATABASES_DIR}/campaign${campaign_id}

# Steps:
#   1. Import Labelme.
#   2. Sync objectids with dirty cropped database in order to have transforms.
#   3. Revert objects.
#   4. Add stamp object properties from the dirty cropped database.
#   5. Make the original dirty database without stamp objects.
#   6. Add the original dirty database without stamp objects.

# ASSUME: all databases have rootdir at $ROOTDIR.

# This script correctly handles:
#   - Moved rectangles.
#   - Moved polygons.
#   - Deleted objects.
#   - Previously existing properties.
# It does NOT correctly handle:
#   - New objects (because new objects don't have transforms in properties.)
#   - Moved objects with no intersection with the dirty objects 
#     (because we use intersection to determine the object correspondence.)\

# Dirty cropped database has correct `objectid` in "objects".
# Clean cropped database has correct `bbox` and `name` in "objects", "polygons", and "properties".

temp_db_name="${clean_folder}-temp.db"  # The location for intermediate db.
rm -f "labelme/${temp_db_name}"
ls "labelme/${dirty_folder}.db"    # Check that the database exists.
python -m shuffler \
    -o "labelme/${temp_db_name}" \
    --rootdir ${ROOT_DIR} \
  importLabelme \
    --images_dir      "${LABELME_DIR}/campaign${campaign_id}/${clean_folder}/Images" \
    --annotations_dir "${LABELME_DIR}/campaign${campaign_id}/${clean_folder}/Annotations" \| \
  moveMedia \
    --image_path $(realpath --relative-to=${ROOT_DIR} "${LABELME_DIR}/campaign${campaign_id}/${dirty_folder}/Images") \| \
  syncObjectidsWithDb \
    --ref_db_file "labelme/${dirty_folder}.db" --IoU_threshold 0.0001

sqlite3 "labelme/${temp_db_name}" " 
  UPDATE objects SET name = CAST(name AS TEXT);
  UPDATE objects SET name='??' WHERE name = 'unclear';
"

# importLabelme adds property keys but not values. That's useless.
sqlite3 "labelme/${temp_db_name}" " 
  DELETE FROM properties;
  ATTACH 'labelme/${dirty_folder}.db' AS ref;
  INSERT INTO properties(id,objectid,key,value) SELECT id,objectid,key,value FROM ref.properties;
  DELETE FROM properties WHERE objectid NOT IN (SELECT objectid FROM objects);
"

# Show what changed.
echo "Out: labelme/${temp_db_name}"
echo "Old: labelme/${dirty_folder}.db"
python -m shuffler -i "labelme/${temp_db_name}" diffDb --ref_db_file "labelme/${dirty_folder}.db"

# Get pages from the previous version.
python -m shuffler -i ${dirty_db_path} -o ${dirty_db_path}.onlypages.db \
  filterObjectsSQL --sql "SELECT objectid FROM objects WHERE name NOT LIKE '%page%'" --delete

python -m shuffler -i labelme/${temp_db_name} -o ${clean_db_path} \
  revertObjectTransforms \| \
  sql --sql "DELETE FROM images" \| \
  addDb --db_file ${dirty_db_path}.onlypages.db

# Compare with the original to see how many bounding boxes and names have changed.
sqlite3 ${clean_db_path} "
  SELECT 'Total objects in cleaned db ', COUNT(1) FROM objects;
  ATTACH '${dirty_db_path}' AS ref;
  SELECT 'Total objects in dirty and cleaned db ', COUNT(1) FROM objects o1 JOIN ref.objects o2 ON o1.objectid = o2.objectid WHERE o1.imagefile == o2.imagefile;
  SELECT 'Bounding boxes moved by avg dx ', AVG(ABS(o1.x1 - o2.x1)) FROM objects o1 JOIN ref.objects o2 ON o1.objectid = o2.objectid;
  DETACH ref;
"
