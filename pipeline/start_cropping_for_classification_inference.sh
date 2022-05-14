#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Start the job of cropping stamps out of a database for the purpose of cleaning.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version IN_VERSION
     --out_version OUT_VERSION
     --size SIZE
     --stamp_threshold STAMP_THRESHOLD
     --page_threshold PAGE_THRESHOLD
     --expand_percent EXPAND_PERCENT (0.5, 0.2, 0, etc)
     --dry_run_submit DRY_RUN_SUBMIT

Example:
  $PROGNAME
     --campaign_id 8
     --in_version 3
     --out_version 4

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (required) The version suffix of the database to crop.
  --out_version
      (required) The version suffix of the filtered (and also cropped) database.
  --stamp_threshold
      (optional) Stamp detections under the threshold are deleted. Default: 0.3.
  --page_threshold
      (optional) Page detections under the threshold are deleted. Default: 0.9.
  --expand_percent
      (optional) Stamps are expanded to be further cropped by classificsation.
                 Should be the same as expansion for training. Default: 0.5.
  --size
      (optional) Resized to squares of 'size x size' after crop. Default: 260.
  --dry_run_submit
      (optional) Enter 1 to NOT submit jobs. Default: "0"
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "out_version"
    "stamp_threshold"
    "page_threshold"
    "expand_percent"
    "size"
    "dry_run_submit"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
stamp_threshold=0.3
page_threshold=0.7
expand_percent=0.5
dry_run_submit=0
size=260

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
        --stamp_threshold)
            stamp_threshold=$2
            shift 2
            ;;
        --page_threshold)
            page_threshold=$2
            shift 2
            ;;
        --expand_percent)
            expand_percent=$2
            shift 2
            ;;
        --size)
            size=$2
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

echo "campaign_id:            ${campaign_id}"
echo "in_version:             ${in_version}"
echo "out_version:            ${out_version}"
echo "stamp_threshold:        ${stamp_threshold}"
echo "page_threshold:         ${page_threshold}"
echo "expand_percent:         ${expand_percent}"
echo "size:                   ${size}"
echo "dry_run_submit:         ${dry_run_submit}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}

shuffler_bin=${SHUFFLER_DIR}/shuffler.py

in_1800x1200_path=$(get_1800x1200_db_path ${campaign_id} ${in_version})
out_1800x1200_path=$(get_1800x1200_db_path ${campaign_id} ${out_version})
out_6Kx4K_expanded_path=$(get_6Kx4K_db_path ${campaign_id} ${out_version}.expanded${expand_percent})

ls ${in_1800x1200_path}


# Steps: 1) filter uncertain detections, 2) move to 6Kx4K, 3) expand stamps, 4) start cropping.

${shuffler_bin} \
    -i ${in_1800x1200_path} \
    -o ${out_1800x1200_path} \
    filterObjectsSQL --sql "SELECT objectid FROM objects WHERE name = 'stamp' AND score < ${stamp_threshold}" \| \
    filterObjectsSQL --sql "SELECT objectid FROM objects WHERE name = 'page' AND score < ${page_threshold}" \| \
    sql --sql "INSERT INTO properties(objectid,key,value) SELECT objectid,'detection_score',score FROM objects" \| \
    sql --sql "UPDATE objects SET score = 0 WHERE name == 'stamp'"
    # ^^ Want to keep score of 'page' for further visualization (TODO: consider dropping).

${shuffler_bin} \
    -i ${out_1800x1200_path} \
    -o ${out_6Kx4K_expanded_path} \
    --rootdir ${ROOT_DIR} \
    recordPositionOnPage \| \
    moveMedia --image_path "original_dataset" --level 2 --adjust_size \| \
    expandObjects --expand_perc ${expand_percent}

${dir_of_this_file}/../scripts/crop_stamps_job/submit.sh \
  --campaign_id ${campaign_id} \
  --in_version "${out_version}.expanded${expand_percent}" \
  --up_to_now "0" \
  --size ${size} \
  --dry_run ${dry_run_submit}

log_db_version ${campaign_id} ${out_version} "Low confidence detections of stamps and pages are discarded."
echo "Done."
