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
  --stamp_classification_version
      (optional) The version suffix for the automatically detected and 
                 classified stamps. Pages can be there too.
                 Used to evaluate the stamp detector and classifier models.
                 If not given will skip the evaluation.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "stamp_classification_version"
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
        --stamp_classification_version)
            stamp_classification_version=$2
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
echo "stamp_classification_version: ${stamp_classification_version}"
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

if [[ ! -z "$stamp_classification_version" ]]; then
    echo "Working on stamp detector precision-recall curve."

    stamp_evaluated_db_file=$(get_1800x1200_db_path ${campaign_id} ${stamp_classification_version})

    curve_path_pattern="campaign%d/detected-trained-on-campaign3to%d/campaign%d-1800x1200.stamps/precision-recall-stamp.txt"
    metrics_dir="${campaign_dir}/detected-trained-on-campaign3to${previous_campaign_id}/campaign${campaign_id}-1800x1200.stamps"
    mkdir -p ${metrics_dir}
    
    # High IoU threshold captures also adjusting the rectangle.
    ${SHUFFLER_DIR}/shuffler.py \
      -i ${stamp_evaluated_db_file} \
      filterObjectsSQL --sql 'SELECT objectid FROM objects WHERE name LIKE "%page%"' \| \
      evaluateDetection \
        --gt_db_file $(get_1800x1200_db_path ${campaign_id} ${in_version}) \
        --where_object_gt 'name NOT LIKE "%page%"' \
        --evaluation_backend "sklearn-ignore-classes" \
        --IoU_thresh 0.9
    echo "^ this is how many did NOT have to add, remove, or ADJUST."

    # Regular IoU threshold.
    ${SHUFFLER_DIR}/shuffler.py \
      -i ${stamp_evaluated_db_file} \
      filterObjectsSQL --sql 'SELECT objectid FROM objects WHERE name LIKE "%page%"' \| \
      evaluateDetection \
        --gt_db_file $(get_1800x1200_db_path ${campaign_id} ${in_version}) \
        --where_object_gt 'name NOT LIKE "%page%"' \
        --evaluation_backend "sklearn-ignore-classes" \
        --extra_metrics precision_recall_curve \
        --IoU_thresh 0.5 \
        --out_dir ${metrics_dir}
    echo "^ this is how many did NOT have to add or remove."

    # Detection + classification accuracy. Shows how many names did not have to change.
    ${SHUFFLER_DIR}/shuffler.py \
      --logging 30 \
      -i ${stamp_evaluated_db_file} \
      filterObjectsSQL --sql 'SELECT objectid FROM objects WHERE name LIKE "%page%"' \| \
      evaluateDetection \
        --gt_db_file $(get_1800x1200_db_path ${campaign_id} ${in_version}) \
        --where_object_gt 'name NOT LIKE "%page%"' \
        --evaluation_backend "sklearn-all-classes" \
        --IoU_thresh 0.5
    echo "^ this is how many were detected AND classified correctly."

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
echo 'out of total of images in archive:'
sqlite3 "${DATABASES_DIR}/all-1800x1200.db" "SELECT COUNT(1) FROM images"

echo 'Printing number of images per campaign.'
sqlite3 ${uptonow_db_path} \
  "SELECT value, COUNT(DISTINCT(imagefile)) 
   FROM objects o JOIN properties p ON o.objectid = p.objectid
   WHERE key='campaign' GROUP BY value ORDER BY value"

echo 'Labeled total stamps:'
sqlite3 ${uptonow_db_path} "SELECT COUNT(1) FROM objects WHERE name NOT LIKE '%page%'"

echo 'Printing number of stamps per campaign.'
sqlite3 ${uptonow_db_path} \
  "SELECT value,COUNT(1) 
   FROM objects o JOIN properties p ON o.objectid = p.objectid
   WHERE key='campaign' AND name NOT LIKE '%page%' GROUP BY value ORDER BY value"

## Make some historgrams of name distributions.

mkdir -p "${campaign_dir}/visualization"

campaign_names=$(seq -s\  ${FIRST_CAMPAIGN_ID} ${campaign_id})

python3 ${SHUFFLER_DIR}/tools/PlotObjectNameHistograms.py \
  --db_path ${uptonow_db_path} \
  --campaign_names ${campaign_names} \
  -o "${campaign_dir}/visualization/campaign${FIRST_CAMPAIGN_ID}to${campaign_id}.count.v${in_version}.png" \
  --fig_height 7 --fig_width 50 --no_xticks

python3 ${SHUFFLER_DIR}/tools/PlotObjectNameHistograms.py \
  --db_path ${uptonow_db_path} \
  --campaign_names ${campaign_names[*]} \
  -o "${campaign_dir}/visualization/campaign${FIRST_CAMPAIGN_ID}to${campaign_id}.count.v${in_version}.atleast25.png" \
  --fig_width 7 --fig_width 20 --at_least 25

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
