#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Upload data from the project dir to the server with LabelMeAnnotationTool server.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --name NAME

Example:
  $PROGNAME
     --campaign_id 7
     --name "clean1"

Options:
  --campaign_id
      (required) The campaign id.
  --name
      (required) The folder name, where to upload the data from.
                 Normally can take values: "initial", "clean1", "clean2", "clean3", etc.
                 "initial" corresponds to initial labeling of original images.
                 "cleanN" corresponds to cleaning using tiled "collage" images.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "name"
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
        --name)
            name=$2
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
if [ -z "$name" ]; then
  echo "Argument 'name' is required."
  exit 1
fi

echo "campaign_id:  ${campaign_id}"
echo "name:         ${name}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

# Source directory.
dir_to_upload_from="${LABELME_DIR}/${name}"
echo "Will upload from directory: '${dir_to_upload_from}'"

###    PUT YOUR CODE HERE    ###
labelme_server_full_path="/var/www/html/LabelMeAnnotationTool"
full_campaign_name="campaign${campaign_id}/${name}"
source_dir_full_path=${dir_to_upload_from}/${full_campaign_name}
target_dir_full_path=${labelme_server_full_path}/${full_campaign_name}
annotations_folder_name="Annotations"
images_folder_name="Images"

# check dir exists ${source_dir_full_path}/Annotations
# check dir exists ${source_dir_full_path}/Images
  check_dirs_exist ${source_dir_full_path}

# check number of files are the same ${source_dir_full_path}/Annotations, ${source_dir_full_path}/Images
  check_equal_number_of_files  # ${source_dir_full_path}

# copy contents ${source_dir_full_path}/Images ${target_dir_full_path}/Images
# copy contents ${source_dir_full_path}/Annotations ${target_dir_full_path}/Annotations
  copy_contents

change JPG extensions in Annotations files to lowercase
change directory tag in Annotations files
set permissions to apache-writable


function check_dirs_exist() {
  if [ -d ${source_dir_full_path}/${annotations_folder_name} && -d ${source_dir_full_path}/${images_folder_name} ]
  then
    echo "Reading content from directory ${source_dir_full_path}."
    return 0
  else
    echo "Error: Directory ${source_dir_full_path} does not exists."
    return 1
  fi
}

function check_equal_number_of_files() {
  number_of_files_annotations=$(ls ${source_dir_full_path}/Annotations | wc -l)
  number_of_files_images=$(ls ${source_dir_full_path}/Images | wc -l)
  return [[ ${number_of_files_annotations} -eq ${number_of_files_images ]]
}

function copy_contents() {
  cp -rfpv ${source_dir_full_path}/${annotations_folder_name} ${target_dir_full_path}/${annotations_folder_name}/
  cp -rfpv ${source_dir_full_path}/${images_folder_name}/*jpg ${target_dir_full_path}/${images_folder_name}/
}

function annotations_JPG_to_lowercase() {
  for i in ${target_dir_full_path}/${images_folder_name}/*JPG; do mv "${i}" "${i%.*}".jpg; done
  for i in ${target_dir_full_path}/${annotations_folder_name}/*xml; do sed -i -e 's_<folder>.*</folder>_<folder>${full_campaign_name}</folder>_' -e 's_.JPG_.jpg_' "${i}"; done
}
echo "Done."
