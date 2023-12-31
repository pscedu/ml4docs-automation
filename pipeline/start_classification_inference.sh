#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Predict stamp class for a new campaign.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version IN_VERSION
     --out_version OUT_VERSION
     --model_campaign_id MODEL_CAMPAIGN_ID
     --set_id SET_ID
     --run_id RUN_ID
     --dry_run_submit DRY_RUN_SUBMIT

Example:
  $PROGNAME
     --campaign_id 8
     --in_version 2

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version suffix of the input database.
  --out_version
      (optional) The version of the output database. 
      If not provided, will not symlink. Provide when using in the pipeline.
      Do NOT provide when evaluating a model from a previous campaign.
  --model_campaign_id
      (optional) The version of the campaign with trained model. 
      The default is campaign_id-1.
  --set_id
      (optional) Which set of models to use for the inference.
  --run_id
      (required) Id of run. Example: 0.
  --dry_run_submit
      (optional) Enter 1 to NOT submit jobs. Default: "0"
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "out_version"
    "model_campaign_id"
    "set_id"
    "run_id"
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
set_id="expand0.5.size260"
run_id="best"

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
        --model_campaign_id)
            model_campaign_id=$2
            shift 2
            ;;
        --set_id)
            set_id=$2
            shift 2
            ;;
        --run_id)
            run_id=$2
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
if [ -z "$model_campaign_id" ]; then
  model_campaign_id=$((campaign_id-1))
  echo "Automatically setting model_campaign_id to ${model_campaign_id}."
fi

echo "campaign_id:            ${campaign_id}"
echo "in_version:             ${in_version}"
echo "out_version:            ${out_version}"
echo "model_campaign_id:      ${model_campaign_id}"
echo "set_id:                 ${set_id}"
echo "run_id:                 ${run_id}"
echo "dry_run_submit:         ${dry_run_submit}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh
source ${dir_of_this_file}/../path_generator.sh

out_db_path=$(get_classified_cropped_db_path ${campaign_id} ${in_version} ${model_campaign_id} ${set_id} ${run_id})
echo "Will write the output database to ${out_db_path}"
mkdir -p $(dirname ${out_db_path})

# Create a bad link for now. It should become a good link once the inference is complete.
if [ -z "$out_version" ]; then
  echo "out_version is not provided, the classified database will not be symlinked."
else
  symlink_db_path="$(get_cropped_db_path ${campaign_id} ${out_version}.${set_id})"
  echo "Symlinking ${out_db_path} to ${symlink_db_path}."
  rm -f ${symlink_db_path}  # Remove the symlink if it exists.
  ln -s ${out_db_path} ${symlink_db_path}
fi

${dir_of_this_file}/../scripts/classification_inference_pel/submit.sh \
  --in_db_file "$(get_cropped_db_path ${campaign_id} ${in_version}.${set_id})" \
  --out_db_file ${out_db_path} \
  --model_campaign_id ${model_campaign_id} \
  --set_id ${set_id} \
  --run_id ${run_id} \
  --dry_run ${dry_run_submit}

log_db_version ${campaign_id} ${out_version} "Stamps are classified."
echo "Done."
