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
  --source_path
      (required) The folder name from which the new files are being read for uploading
                 to LabelMe.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "name"
    "source_path"
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
        --source_path)
            source_path=$2
            shift 2
            ;;
        --) # No more arguments
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
if [ -z "$source_path" ]; then
  echo "Argument 'source_path' is required."
  exit 1
fi

echo "campaign_id:  ${campaign_id}"
echo "name:         ${name}"
echo "source_path:  ${source_path}"

# The end of the parsing code.
################################################################################

## Import all constants.
#dir_of_this_file=$(dirname $(readlink -f $0))
#source ${dir_of_this_file}/../constants.sh
#
## Source directory.
#dir_to_upload_from="${LABELME_DIR}/${name}"
#echo "Will upload from directory: '${dir_to_upload_from}'"

###    PUT YOUR CODE HERE    ###
function check_exit_status()
{
    if [ $1 -eq 0 ]; then
        continue
    else
        echo "ERROR: An error has occurred!"
        exit 2
    fi
}

function check_dirs_exist() {
  if [[ -d ${FULL_PATH_SOURCE_DIR}/${ANNOTATIONS_FOLDER_NAME} && -d ${FULL_PATH_SOURCE_DIR}/${IMAGES_FOLDER_NAME} ]]
  then
    echo "Reading content from directory ${FULL_PATH_SOURCE_DIR}."
    return 0
  else
    echo "Error: Directory ${FULL_PATH_SOURCE_DIR} does not exist."
    return 1
  fi
}

FULL_PATH_TARGET_DIR="/var/www/html/LabelMeAnnotationTool"
FULL_CAMPAIGN_NAME="campaign${campaign_id}/${name}"
echo "The campaign name to use will be: ${FULL_CAMPAIGN_NAME}"
echo "Would like to change it? (y/n)"
read yn_dialog
if [[ "${yn_dialog}" == "y" ]]; then
    echo "Please input the new campaign name to use:"
    read FULL_CAMPAIGN_NAME
fi
FULL_PATH_SOURCE_DIR=${source_path}
ANNOTATIONS_FOLDER_NAME="Annotations"
IMAGES_FOLDER_NAME="Images"

# Check the origin directories exist
check_dirs_exist ${FULL_PATH_SOURCE_DIR}
check_exit_status $?

# Make sure the new images are set as underscore extension (.jpg)
number_of_images=$(ls "${FULL_PATH_SOURCE_DIR}/${IMAGES_FOLDER_NAME}/*jpg" | wc -l)
check_exit_status $?
number_of_labels=$(ls "${FULL_PATH_SOURCE_DIR}/${ANNOTATIONS_FOLDER_NAME}/*xml" | wc -l)
check_exit_status $?

# check number of files are the same ${FULL_PATH_SOURCE_DIR}/Annotations, ${FULL_PATH_SOURCE_DIR}/Images
if [[ -v number_of_images ]] && [[ -v number_of_labels ]] && [ "${number_of_images}" -eq "${number_of_labels}" ] && [ "${number_of_images}" -gt 0 ]; then
    # Check if both directories exist.
    if [ ! -d "${FULL_PATH_SOURCE_DIR}/${IMAGES_FOLDER_NAME}/" ]; then
        echo "Directory ${FULL_PATH_SOURCE_DIR}/${IMAGES_FOLDER_NAME}/ DOES NOT exist."
        exit 2
    fi
    if [ ! -d "${FULL_PATH_SOURCE_DIR}/${ANNOTATIONS_FOLDER_NAME}/" ]; then
        echo "Directory ${FULL_PATH_SOURCE_DIR}/${ANNOTATIONS_FOLDER_NAME}/ DOES NOT exist."
        exit 2
    fi
else
    # If there is a mismatch regarding the number of images, provide more information.
    echo "Wrong number of images and/or labels at the source path ${FULL_PATH_SOURCE_DIR}"
    echo "Number of images: ${number_of_images}"
    echo "Number of labels: ${number_of_labels}"
    NUMBER_OF_UPPERCASE_FILES=$(find "${FULL_PATH_SOURCE_DIR}/${IMAGES_FOLDER_NAME}/" -iname "*jpg\|*xml" | wc -l)
    # if the images are in the location but the extensions are not as expected, show more information.
    if [[ $NUMBER_OF_UPPERCASE_FILES -gt 0 ]]; then
        echo "You seem to have uppercase files. For renaming them, these commands might be handy:"
        echo find "${FULL_PATH_SOURCE_DIR}/${IMAGES_FOLDER_NAME}/" -iname "*jpg\|*xml"

        # Change JPG extensions in Annotations files to lowercase
        echo cd "${FULL_PATH_SOURCE_DIR}/${IMAGES_FOLDER_NAME}/"
        echo for i in *JPG; do cp "${i}" "${i%.*}".jpg; done
        echo cd -
        # Change XML extensions in Annotations files to lowercase
        echo cd "${FULL_PATH_SOURCE_DIR}/${ANNOTATIONS_FOLDER_NAME}/"
        echo for i in *xml; do sed -i -e 's_.JPG_.jpg_' "${i}"; done
        echo for i in *XML; do cp "${i}" "${i%.*}".xml; done
        echo cd -
    fi
    exit 2
fi

# copy contents
# Set umask
umask 0002
# Create target directory
mkdir -p "${FULL_PATH_TARGET_DIR}/${IMAGES_FOLDER_NAME}/${FULL_CAMPAIGN_NAME}"
chmod g+sw,o=r "${FULL_PATH_TARGET_DIR}/${IMAGES_FOLDER_NAME}/${FULL_CAMPAIGN_NAME}"
mkdir -p "${FULL_PATH_TARGET_DIR}/${ANNOTATIONS_FOLDER_NAME}/${FULL_CAMPAIGN_NAME}"
chmod g+sw,o=r "${FULL_PATH_TARGET_DIR}/${ANNOTATIONS_FOLDER_NAME}/${FULL_CAMPAIGN_NAME}"
echo "Copying images..."
cp -v "${FULL_PATH_SOURCE_DIR}/${IMAGES_FOLDER_NAME}/*jpg" "${FULL_PATH_TARGET_DIR}/${IMAGES_FOLDER_NAME}/${FULL_CAMPAIGN_NAME}" && "Copied."
check_exit_status $?
echo "Copying annotations..."
cp -v "${FULL_PATH_SOURCE_DIR}/${ANNOTATIONS_FOLDER_NAME}/*xml" "${FULL_PATH_TARGET_DIR}/${ANNOTATIONS_FOLDER_NAME}/${FULL_CAMPAIGN_NAME}" && "Copied."
check_exit_status $?

# Change directory tag in Annotations files
cd "${FULL_PATH_TARGET_DIR}/${ANNOTATIONS_FOLDER_NAME}/${FULL_CAMPAIGN_NAME}"
# Check if the folder tag matches
grep_result_lines = $(grep "<folder>${FULL_CAMPAIGN_NAME}</folder>" ${FULL_PATH_TARGET_DIR}/${ANNOTATIONS_FOLDER_NAME}/${FULL_CAMPAIGN_NAME}/*xml | wc -l)
if [ $grep_result_lines -eq 0 ]; then
    echo "Fixing the contents of the xml files as the folder tag is wrong..."
    for i in *xml; do sed -i -e "s_<folder>\(.*\)</folder>_<folder>${FULL_CAMPAIGN_NAME}</folder>_" "${i}"; done
cd -

# Set permissions to apache-writable
cd "${FULL_PATH_TARGET_DIR}/${ANNOTATIONS_FOLDER_NAME}/${FULL_CAMPAIGN_NAME}"
chmod o+w *xml
cd -

echo "Done with the file copy. Now go create the new campaign on the LabelMe Navigator..."
