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
  --at_least_for_decade
      (optional) The number of names for the "decades" plot. Default: 200.
  --at_least_for_histogram
      (optional) The number of names for the histogram plot. Default: 50.
EO
}

ARGUMENT_LIST=(
    "campaign_id"
    "in_version"
    "at_least_for_decade"
    "at_least_for_histogram"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
in_version="latest"
at_least_for_decade=200
at_least_for_histogram=50

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
        --at_least_for_decade)
            at_least_for_decade=$2
            shift 2
            ;;
        --at_least_for_histogram)
            at_least_for_histogram=$2
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
echo "previous_campaign_id:   ${previous_campaign_id}"
echo "at_least_for_decade:    ${at_least_for_decade}"
echo "at_least_for_histogram: ${at_least_for_histogram}"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
echo "Conda environment is activated: '${CONDA_SHUFFLER_ENV}'"

# Save the output, because it has numbers.
# Redirect stdout ( > ) into a named pipe ( >() ) running "tee"
log_file="${campaign_dir}/visualization/statistics_of_campaign.txt"
exec > >(tee -i ${log_file})

FIRST_CAMPAIGN_ID=3

campaign_dir=$(get_campaign_dir ${campaign_id})

uptonow_db_path=$(get_1800x1200_uptonow_db_path ${campaign_id} ${in_version})
echo "Visualizing data from ${uptonow_db_path}"

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

python3 ${SHUFFLER_DIR}/shuffler/tools/plot_object_name_histograms.py \
  --db_path ${uptonow_db_path} \
  --campaign_names ${campaign_names} \
  -o "${campaign_dir}/visualization/campaign${FIRST_CAMPAIGN_ID}to${campaign_id}.count.v${in_version}.png" \
  --fig_height 7 --fig_width 50 --no_xticks

python3 ${SHUFFLER_DIR}/shuffler/tools/plot_object_name_histograms.py \
  --db_path ${uptonow_db_path} \
  --campaign_names ${campaign_names[*]} \
  -o "${campaign_dir}/visualization/campaign${FIRST_CAMPAIGN_ID}to${campaign_id}.count.v${in_version}.atleast${at_least_for_histogram}.png" \
  --fig_width 7 --fig_width 20 --at_least ${at_least_for_histogram}

## Distribution by decade.

python -m shuffler \
  -i ${uptonow_db_path} \
  sql --sql "DELETE FROM objects WHERE name IN (SELECT DISTINCT(name) FROM objects GROUP BY name HAVING COUNT(1) < ${at_least_for_decade})" \| \
  sql --sql "DELETE FROM objects WHERE name LIKE '%page%' OR name LIKE '%??%'" \| \
  plotHistogram \
    --sql_stacked "SELECT value,name FROM properties JOIN objects ON properties.objectid = objects.objectid WHERE key='decade'" \
    --xlabel "decade" \
    --colormap "tab20" \
    --out_path "${campaign_dir}/visualization/campaign${FIRST_CAMPAIGN_ID}to${campaign_id}.v${in_version}.decade.png"



echo "Done."
