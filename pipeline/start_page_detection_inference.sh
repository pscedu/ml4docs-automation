#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Start ML-detection of stamps in the newly created campaign.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version IN_VERSION
     --out_version OUT_VERSION
     --dry_run_submit DRY_RUN_SUBMIT

Example:
  $PROGNAME
     --campaign_id 7
     --in_version 1

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version of the input database.
  --out_version
      (required) The version of the output database. The default is in_version+1.
  --dry_run_submit
      (optional) Enter 1 to NOT submit jobs. Default: "0"
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "out_version"
    "dry_run_submit"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
dry_run_submit=0

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
        --dry_run_submit)
            dry_run_submit=$2
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
  out_version=$((in_version+1))
  echo "Automatically setting out_version to ${out_version}."
fi

previous_campaign_id=$((campaign_id-1))

echo "campaign_id:            ${campaign_id}"
echo "previous_campaign_id:   ${previous_campaign_id}"
echo "in_version:             ${in_version}"
echo "out_version:            ${out_version}"
echo "dry_run_submit:         ${dry_run_submit}"


# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

scripts/detection_inference_retinanet_jobs/submit.sh \
  --in_db_file "$(get_1800x1200_db_path ${campaign_id} ${in_version})" \
  --out_db_file "$(get_1800x1200_db_path ${campaign_id} ${out_version})" \
  --model_campaign_id ${previous_campaign_id} \
  --set_id "set-page-1800x1200" \
  --class_name "page" \
  --dry_run ${dry_run_submit}

echo "Page inference started."
