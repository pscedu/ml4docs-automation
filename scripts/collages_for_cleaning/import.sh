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
     --dirty_db_name DIRTY_DB_NAME
     --clean_db_name CLEAN_DB_NAME
     --dirty_folder DIRTY_FOLDER_NAME
     --clean_folder CLEAN_FOLDER_NAME

Example:
  $PROGNAME
     --campaign_id 5
     --dirty_db_name "campaign5-6Kx4K.v5.db"
     --clean_db_name "campaign5-6Kx4K.v6.db"
     --dirty_folder "cleaning1"
     --clean_folder "cleaning1-labeled"

Options:
  --campaign_id
      (required) The campaign id where all the files reside.
  --dirty_db_name
      (required) Input database. Should be in "\${DATABASE_DIR}/campaign/\${campaign_id}".
  --clean_db_name
      (required) Output database. Should be in "\${DATABASE_DIR}/campaign/\${campaign_id}".
  --dirty_folder
      (required) Will store temporary images before cleaning. 
                 Will look for it at "\${DATABASE_DIR}/campaign/\${campaign_id}/labelme/".
  --clean_folder
      (required) Will store temporary images after cleaning/
                 Will look for it at "\${DATABASE_DIR}/campaign/\${campaign_id}/labelme/".
  --use_sync_objectids
      (optional) If 1, will use bboxes from dirty_db_name, just change names.
                 This is more accurate if boxes were not moved.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "dirty_folder"
    "clean_folder"
    "dirty_db_name"
    "clean_db_name"
    "use_sync_objectids"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
use_sync_objectids=0

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
        --dirty_db_name)
            dirty_db_name=$2
            shift 2
            ;;
        --clean_db_name)
            clean_db_name=$2
            shift 2
            ;;
        --use_sync_objectids)
            use_sync_objectids=$2
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
if [ -z "$dirty_db_name" ]; then
  echo "Argument 'dirty_db_name' is required."
  exit 1
fi
if [ -z "$clean_db_name" ]; then
  echo "Argument 'clean_db_name' is required."
  exit 1
fi

# The end of the parsing code.
################################################################################


shuffler_bin=${SHUFFLER_DIR}/shuffler.py

cd ${DATABASES_DIR}/campaign${campaign_id}

temp_db_name="temp.db"
# labelme/${temp_db_name}    is an location for intermediate db.
# labelme/${clean_folder}    is an location for intermediate images.
ls labelme/${dirty_folder}.db
rm -f "labelme/${temp_db_name}"
${shuffler_bin} \
    -o "labelme/${temp_db_name}" \
    --rootdir ${ROOT_DIR} \
  importLabelme \
    --images_dir      "${LABELME_DIR}/campaign${campaign_id}/${clean_folder}/Images" \
    --annotations_dir "${LABELME_DIR}/campaign${campaign_id}/${clean_folder}/Annotations" \| \
  moveMedia --image_path $(realpath --relative-to=${ROOT_DIR} ${DATABASES_DIR}/campaign${campaign_id}/labelme/${dirty_folder}) \| \
  syncObjectidsWithDb --ref_db_file "labelme/${dirty_folder}.db" --IoU_threshold 0.3

sqlite3 labelme/${temp_db_name} "
  UPDATE objects SET name = CAST(name AS TEXT);
  UPDATE objects SET name='??' WHERE name = 'unclear';
"

sqlite3 labelme/${temp_db_name} "
  ATTACH 'labelme/${dirty_folder}.db' AS ref;
  INSERT INTO properties(id,objectid,key,value) SELECT id,objectid,key,value FROM ref.properties;
"

# Show what changed.
echo "Out: labelme/${temp_db_name}"
echo "Old: labelme/${dirty_folder}.db"
${shuffler_bin} -i labelme/${temp_db_name} \
  diffDb --ref_db_file labelme/${dirty_folder}.db

if [ ${use_sync_objectids} != "0" ]; then
  # This clause is only for debugging.

  # Sync if revert does not work.
  cp ${dirty_db_name} ${clean_db_name}
  sqlite3 ${clean_db_name} "
    ATTACH 'labelme/${temp_db_name}' AS new;
    SELECT COUNT(1) FROM objects;
    SELECT COUNT(DISTINCT(name)) FROM objects;
    DELETE FROM objects 
            WHERE objectid NOT IN (SELECT objectid FROM new.objects) AND name NOT LIKE '%page%';
    UPDATE objects SET name = (SELECT name FROM new.objects o2 WHERE objects.objectid=o2.objectid);
    SELECT COUNT(1) FROM objects;
    SELECT COUNT(name) FROM objects;
  "

else

  # Move the image dir to the same one as before the labelling.
  # Keep only images.
  cp ${dirty_db_name} ${dirty_db_name}.empty.db
  sqlite3 ${dirty_db_name}.empty.db "
    DELETE FROM objects; DELETE FROM properties; DELETE FROM polygons;"
  
  ${shuffler_bin} \
    -i labelme/${temp_db_name} \
    -o ${clean_db_name} \
    revertObjectTransforms \| \
    sql --sql "DELETE FROM images" \| \
    addDb --db_file ${dirty_db_name}.empty.db

  # Get pages from the previous version.
  ${shuffler_bin} -i ${dirty_db_name} -o ${dirty_db_name}.onlypages.db \
    filterObjectsSQL --sql "SELECT objectid FROM objects WHERE name NOT LIKE '%page%'" 

  ${shuffler_bin} -i ${clean_db_name} -o ${clean_db_name} \
    addDb --db_file ${dirty_db_name}.onlypages.db
  
  # Compare with the original to see how many bounding boxes and names have changed.
  sqlite3 ${clean_db_name} "
    SELECT 'Total objects in cleaned db ', COUNT(1) FROM objects;
    ATTACH '${dirty_db_name}' AS ref;
    SELECT 'Total objects in dirty and cleaned db ', COUNT(1) FROM objects o1 JOIN ref.objects o2 ON o1.objectid = o2.objectid WHERE o1.imagefile == o2.imagefile;
    SELECT 'Bounding boxes moved by avg dx ', AVG(ABS(o1.x1 - o2.x1)) FROM objects o1 JOIN ref.objects o2 ON o1.objectid = o2.objectid;
    DETACH ref;
  "

fi

