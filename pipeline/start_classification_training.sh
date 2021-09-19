#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Select a new campaign from unlabeled images.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID

Example:
  $PROGNAME
     --campaign_id 6

Options:
  --campaign_id
      (required) The campaign id.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
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

echo "campaign_id:            ${campaign_id}"

# The end of the parsing code.
################################################################################

${dir_of_this_file}/../scripts/train_classification/submit.sh --campaign_id ${campaign_id}

echo "Started."
