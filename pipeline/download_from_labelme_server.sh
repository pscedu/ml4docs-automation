#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Download data from the server with LabelMeAnnotationTool server to the project dir.

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
      (required) The folder name, where to download the results to.
                 Suffix "-labeled" will be added to it.
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

# Target directory.
dir_to_download_to="${LABELME_DIR}/${name}-labeled"
echo "Will download to directory: '${dir_to_download_to}'"

###    PUT YOUR CODE HERE    ###



echo "Done."
