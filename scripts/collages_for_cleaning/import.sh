#!/bin/bash

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
This scripts imports tiles after cleaning in Labelme.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_NAME
     --db_name DB_NAME
     --folder OUTPUT_FOLDER
     --project_dir PROJECT_DIR
     --import_folder IMPORT_FOLDER

Example:
  $PROGNAME
     --campaign_id 5 \
     --dirty_db_name "campaign3to5-6Kx4K.v5.db" \
     --clean_db_name "campaign3to5-6Kx4K.v6.db" \
     --dirty_folder "cleaning-v5-campaign3to5" \
     --clean_folder "cleaning-v5-campaign3to5-done"

Options:
  --campaign_id
      (required) The campaign id where all the files reside.
  --dirty_folder
      (required) Labelme prepared for cleaning. Will look at it in "etoropov/campaign\$\{campaign_id\}/labelme/".
  --clean_folder
      (required) Labelme after cleaning. Will look at this folder at "shared/data/campaign\$\{campaign_id\}/".
  --dirty_db_name
      (required) Input database. Will look for this file at "etoropov/campaign\$\{campaign_id\}/".
  --clean_db_name
      (required) Output database. Will be at "etoropov/campaign\$\{campaign_id\}/".
  --project_dir
      (optional) The directory of the whole project on bridges/bridges2.
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
    "project_dir"
    "use_sync_objectids"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
project_dir="/ocean/projects/hum180001p"
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
        --project_dir)
            project_dir=$2
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


shuffler_bin=${project_dir}/shared/src/shuffler/shuffler.py

cd ${project_dir}/etoropov/campaign${campaign_id}

# labelme/${clean_folder}.db is an location for intermediate db.
# labelme/${clean_folder}    is an location for intermediate images.
${shuffler_bin} \
    -o "labelme/${clean_folder}.db" \
    --rootdir "${project_dir}/shared/data" \
  importLabelme \
    --images_dir      "${project_dir}/shared/data/campaign${campaign_id}/${clean_folder}/Images" \
    --annotations_dir "${project_dir}/shared/data/campaign${campaign_id}/${clean_folder}/Annotations" \| \
  moveMedia --image_path "../../etoropov/campaign${campaign_id}/labelme/${dirty_folder}-temp" \| \
  syncObjectidsWithDb --ref_db_file "${project_dir}/etoropov/campaign${campaign_id}/labelme/${dirty_folder}.db" --IoU_threshold 0.3
status=$?
if [ ${status} -ne 0 ]; then
  echo "Failed to import from Labelme."
  exit ${status}
fi

sqlite3 labelme/${clean_folder}.db "
  UPDATE objects SET name = CAST(name AS TEXT);
  UPDATE objects SET name='??' WHERE name = 'unclear';
"

sqlite3 labelme/${clean_folder}.db "
  ATTACH 'labelme/${dirty_folder}.db' AS ref;
  INSERT INTO properties(id,objectid,key,value) SELECT id,objectid,key,value FROM ref.properties;
"

# Show what changed.
${shuffler_bin} -i labelme/${clean_folder}.db \
  diffDb --ref_db_file labelme/${dirty_folder}.db

if [ ${use_sync_objectids} != "0" ]; then

  # Sync if revert does not work.
  cp ${dirty_db_name} ${clean_db_name}
  sqlite3 ${clean_db_name} "
    ATTACH 'labelme/${clean_folder}.db' AS new;
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
  sqlite3 ${dirty_db_name}.empty.db "DELETE FROM objects; DELETE FROM properties; DELETE FROM polygons;"
  
  ${shuffler_bin} \
    -i labelme/${clean_folder}.db \
    -o ${clean_db_name} \
    revertObjectTransforms \| \
    sql --sql "DELETE FROM images" \| \
    addDb --db_file ${dirty_db_name}.empty.db

  # Get pages from the previous version.
  ${shuffler_bin} -i ${dirty_db_name} -o ${dirty_db_name}.onlypages.db \
    filterObjectsSQL --sql "SELECT objectid FROM objects WHERE name NOT LIKE '%page%'" 

  ${shuffler_bin} \
    -i ${clean_db_name} \
    -o ${clean_db_name} \
    addDb --db_file ${dirty_db_name}.onlypages.db

  # Compare with the original to see how many bounding boxes and names have changed.
  sqlite3 ${clean_db_name} "
    SELECT COUNT(1) FROM objects;
    ATTACH '${dirty_db_name}' AS ref;
    SELECT COUNT(1) FROM objects o1 JOIN ref.objects o2 ON o1.objectid = o2.objectid WHERE o1.imagefile == o2.imagefile;
    SELECT AVG(ABS(o1.x1 - o2.x1)) FROM objects o1 JOIN ref.objects o2 ON o1.objectid = o2.objectid;
    DETACH ref;
  "

fi

${shuffler_bin} -i ${clean_db_name} --rootdir ${project_dir}/shared/data \
  moveMedia --image_path "1800x1200" --level 2 --adjust_size \| \
  writeMedia \
    --media "video" \
    --image_path visualization/${clean_db_name}.avi \
    --with_objects \
    --with_imageid
echo "Made a video at 'visualization/${clean_db_name}.avi'."

