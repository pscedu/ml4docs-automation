#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Write a visualization video from a database. Parameters are picked to fit.

Usage:
  $PROGNAME
     --in_db_file IN_DB_FILE
     --out_video_file OUT_VIDEO_FILE
     --number NUMBER

Example:
  $PROGNAME
     --db_file /ocean/projects/hum180001p/shared/databases/campaign8/campaign8-1800x1200.v3.db

Options:
  --in_db_file
      (required) Path to the database, absolute or relative.
  --out_video_file
      (optional) Path to the output file, absolute or relative.
      The default is in_db_file with the extension changed to avi.
  --number
      (optional) Specify to export a number of images. Default is all images.
EO
}

ARGUMENT_LIST=(
    "in_db_file"
    "out_video_file"
    "number"
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
        --in_db_file)
            in_db_file=$2
            shift 2
            ;;
        --out_video_file)
            out_video_file=$2
            shift 2
            ;;
        --number)
            number=$2
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
if [ -z "$in_db_file" ]; then
  echo "Argument 'in_db_file' is required."
  exit 1
fi
if [ -z "$out_video_file" ]; then
  out_video_file="${in_db_file%.*}.avi"
  echo "Automatically inferred the output video file as: ${out_video_file}"
fi

echo "in_db_file:             ${in_db_file}"
echo "out_video_file:         ${out_video_file}"
echo "number:                 ${number}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh
source ${dir_of_this_file}/../path_generator.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"

# Make a video of all campaigns.
if [ -z "${number}" ]; then
  python -m shuffler -i ${in_db_file} --rootdir ${ROOT_DIR} \
    moveMedia --image_path "1800x1200" --level 2 \| \
    resizeAnnotations \| \
    writeMedia \
        --media "video" \
        --image_path ${out_video_file} \
        --with_objects \
        --with_imageid \
        --overwrite
else
  python -m shuffler -i ${in_db_file} --rootdir ${ROOT_DIR} \
    randomNImages -n ${number} \| \
    moveMedia --image_path "1800x1200" --level 2 \| \
    resizeAnnotations \| \
    writeMedia \
        --media "video" \
        --image_path ${out_video_file} \
        --with_objects \
        --with_imageid \
        --overwrite
fi

echo "Made a video at ${out_video_file}."
