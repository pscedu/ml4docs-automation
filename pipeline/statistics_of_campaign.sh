#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Produce aggregated statistics at the end of a campaign.

Usage:
  $PROGNAME
     --campaign_id CAMPAIGN_ID
     --in_version IN_VERSION

Example:
  $PROGNAME
     --campaign_id 7

Options:
  --campaign_id
      (required) The campaign id.
  --in_version
      (optional) The version suffix of a database. Default: "latest".
  --stamp_detection_version
      (optional) The version suffix for the automatically detected stamps.
                 Used to evaluate the stamp detector model.
                 If not given will skip the evaluation.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "stamp_detection_version"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
in_version="latest"

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
        --stamp_detection_version)
            stamp_detection_version=$2
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

previous_campaign_id=$((${campaign_id} - 1))

echo "campaign_id:            ${campaign_id}"
echo "in_version:             ${in_version}"
echo "stamp_detection_version: ${stamp_detection_version}"
echo "previous_campaign_id:   ${previous_campaign_id}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"


FIRST_CAMPAIGN_ID=3

campaign_dir=$(get_campaign_dir ${campaign_id})

if [[ ! -z "$stamp_detection_version" ]]; then
    echo "Working on stamp detector precision-recall curve."

    curve_path_pattern="campaign%d/detected-trained-on-campaign3to%d/campaign%d-1800x1200.stamps/precision-recall-stamp.txt"
    metrics_dir="${campaign_dir}/detected-trained-on-campaign3to${previous_campaign_id}/campaign${campaign_id}-1800x1200.stamps"
    mkdir -p ${metrics_dir}
    
    # Need the ground truth to have objects named "stamp" (and no pages).
    stamps_gt_file=$(get_1800x1200_db_path ${campaign_id} ${in_version}.stamps)
    echo "Ground truth stamp db:          ${stamps_gt_file}"
    if [[ ! -f ${stamps_gt_file} ]]; then
      echo "Generating ${stamps_gt_file}"
      ${SHUFFLER_DIR}/shuffler.py \
        -i $(get_1800x1200_db_path ${campaign_id} ${in_version}) \
        -o ${stamps_gt_file} \
        filterObjectsSQL \
          --sql "SELECT objectid FROM objects WHERE name LIKE '%page%'" \| \
        sql --sql "UPDATE objects SET name='stamp'"
    fi

    # Make sure the evaluated database has only objects named "stamp".
    # This makes sure the user entered the right `stamp_detection_version`.
    stamp_evaluated_db_file=$(get_1800x1200_db_path ${campaign_id} ${stamp_detection_version})
    echo "Evaluated stamp detection db:   ${stamp_evaluated_db_file}"
    num_non_stamp_names=$(sqlite3 ${stamp_evaluated_db_file} "SELECT COUNT(DISTINCT(name)) FROM objects WHERE name != 'stamp'")
    echo "Number of names that are not stamps in the evaluated db: ${num_non_stamp_names}"
    if [[ ${num_non_stamp_names} -ne 0 ]]; then
      echo "Evaluated db can only have objects of 'stamp' names."
      exit 1
    fi

    ${SHUFFLER_DIR}/shuffler.py \
      -i ${stamp_evaluated_db_file} \
      evaluateDetection \
        --gt_db_file ${stamps_gt_file} \
        --extra_metrics precision_recall_curve \
        --out_dir ${metrics_dir}

    # TODO: use, when Yolo model is trained on first campaigns.
    # python3 ${SHUFFLER_DIR}/tools/PlotDetectionCurvesFromCampaigns.py \
    #   --campaigns_dir ${DATABASES_DIR} \
    #   --curve_path_pattern ${curve_path_pattern} \
    #   --main_campaign_id ${campaign_id} \
    #   --campaign_ids $(seq -s\  ${FIRST_CAMPAIGN_ID} ${campaign_id}) \
    #   --out_plot_path "${campaign_dir}/visualization/detection_curve_of_campaign${campaign_id}.png"
fi

uptonow_db_path=$(get_1800x1200_uptonow_db_path ${campaign_id} ${in_version})
echo "Visualizing data from ${uptonow_db_path}"

## Aggregated.

echo 'Labeled total images:'
sqlite3 ${uptonow_db_path} "SELECT COUNT(1) FROM images"
echo 'outof total of images in archive:'
sqlite3 "${DATABASES_DIR}/all-1800x1200.db" "SELECT COUNT(1) FROM images"

echo 'Printing number of images per campaign.'
sqlite3 ${uptonow_db_path} \
  "SELECT value, COUNT(DISTINCT(imagefile)) 
   FROM objects o JOIN properties p ON o.objectid = p.objectid
   WHERE key='campaign' GROUP BY value ORDER BY value"

echo 'Printing number of stamps per campaign.'
sqlite3 ${uptonow_db_path} \
  "SELECT value,COUNT(1) FROM properties WHERE key='campaign' GROUP BY value ORDER BY value"

## Make some historgrams of name distributions.

python3 ${SHUFFLER_DIR}/tools/PlotObjectNameHistograms.py \
  --db_path ${uptonow_db_path} \
  --campaign_names $(seq -s\  ${FIRST_CAMPAIGN_ID} ${campaign_id}) \
  -o "${campaign_dir}/visualization/campaign${FIRST_CAMPAIGN_ID}to${campaign_id}.count.v${in_version}.ylog.png" \
  --legend_entries  "cycle 1" "cycle 2" "cycle 3" "cycle 4" "cycle 5" "cycle 6" \
  --fig_height 7 --fig_width 50 --no_xticks --ylog

python3 ${SHUFFLER_DIR}/tools/PlotObjectNameHistograms.py \
  --db_path ${uptonow_db_path} \
  --campaign_names $(seq -s\  ${FIRST_CAMPAIGN_ID} ${campaign_id}) \
  -o "${campaign_dir}/visualization/campaign${FIRST_CAMPAIGN_ID}to${campaign_id}.count.v${in_version}.atleast25.ylog.png" \
  --legend_entries  "cycle 1" "cycle 2" "cycle 3" "cycle 4" "cycle 5" "cycle 6" \
  --fig_width 7 --fig_width 20 --at_least 25 --ylog

## Distribution by decade.

${SHUFFLER_DIR}/shuffler.py \
  -i ${uptonow_db_path} \
  sql --sql "DELETE FROM objects WHERE name IN (SELECT DISTINCT(name) FROM objects GROUP BY name HAVING COUNT(1) < 55)" \| \
  sql --sql "DELETE FROM objects WHERE name LIKE '%page%' OR name LIKE '%??%'" \| \
  plotHistogram \
    --sql_stacked "SELECT value,name FROM properties JOIN objects ON properties.objectid = objects.objectid WHERE key='decade'" \
    --xlabel "decade" \
    --colormap "tab20" \
    --out_path "${campaign_dir}/visualization/campaign${FIRST_CAMPAIGN_ID}to${campaign_id}.v${in_version}.decade.png"



echo "Done."
