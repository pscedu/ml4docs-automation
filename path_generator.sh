#!/bin/bash

# Import all constants.
source ./constants.sh

get_campaign_dir () {
    local campaign_id=$1
    echo "${DATABASES_DIR}/campaign${campaign_id}"
}

get_1800x1200_all_db_path() {
    echo "${DATABASES_DIR}/all-1800x1200.db"
}

get_1800x1200_db_path () {
    local campaign_id=$1
    local version=$2
    echo "${DATABASES_DIR}/campaign${campaign_id}/campaign${campaign_id}-1800x1200.v${version}.db"
}
get_6Kx4K_db_path () {
    local campaign_id=$1
    local version=$2
    echo "${DATABASES_DIR}/campaign${campaign_id}/campaign${campaign_id}-6Kx4K.v${version}.db"
}

get_1800x1200_uptonow_db_path () {
    local campaign_id=$1
    local version=$2
    echo "${DATABASES_DIR}/campaign${campaign_id}/campaign3to${campaign_id}-1800x1200.v${version}.db"
}
get_6Kx4K_uptonow_db_path () {
    local campaign_id=$1
    local version=$2
    echo "${DATABASES_DIR}/campaign${campaign_id}/campaign3to${campaign_id}-6Kx4K.v${version}.db"
}

get_detected_db_path() {
    local campaign_id=$1
    local model_campaign_id=$2
    local set_id=$3
    local run_id=$4
    echo "${DATABASES_DIR}/campaign${campaign_id}/campaign${campaign_id}-detected/trained-on-campaign${model_campaign_id}-${set_id}-run${run_id}.db"
}

get_detected_uptonow_db_path() {
    local campaign_id=$1
    local model_campaign_id=$2
    local set_id=$3
    local run_id=$4
    echo "${DATABASES_DIR}/campaign${campaign_id}/campaign3to${campaign_id}-detected/trained-on-campaign${model_campaign_id}-${set_id}-run${run_id}.db"
}

get_classified_cropped_db_path() {
    local campaign_id=$1
    local version=$2
    local model_campaign_id=$3
    local set_id=$4
    local run_id=$5
    echo "${DATABASES_DIR}/campaign${campaign_id}/campaign${campaign_id}.v${version}-classified/trained-on-campaign${model_campaign_id}-${set_id}-run${run_id}.cropped.db"
}

get_cropped_db_path () {
    local campaign_id=$1
    local version=$2
    echo "${DATABASES_DIR}/campaign${campaign_id}/crops/campaign${campaign_id}-6Kx4K.v${version}.cropped.db"
}

get_uptonow_cropped_db_path () {
    local campaign_id=$1
    local version=$2
    echo "${DATABASES_DIR}/campaign${campaign_id}/crops/campaign3to${campaign_id}-6Kx4K.v${version}.cropped.db"
}

get_classification_run_dir() {
    local campaign_id=$1
    local set_id=$2
    local run_id=$3
    echo "${CLASSIFICATION_DIR}/campaign${campaign_id}/${set_id}/run${run_id}"
}

get_classification_experiments_path() {
    local campaign_id=$1
    local set_id=$2
    local run_id=$3
    echo "$(get_classification_run_dir ${campaign_id} ${set_id} ${run_id})/experiments.txt"
}

get_detection_run_dir() {
    local campaign_id=$1
    local set_id=$2
    local run_id=$3
    echo "${DETECTION_DIR}/campaign${campaign_id}/${set_id}/run${run_id}"
}

get_detection_experiments_path() {
    local campaign_id=$1
    local set_id=$2
    local run_id=$3
    echo "$(get_detection_run_dir ${campaign_id} ${set_id} ${run_id})/experiments.txt"
}

get_page_detection_splits_uptonow_dir() {
    local campaign_id=$1
    local in_version=$2
    echo "${DETECTION_DIR}/campaign3to${campaign_id}/splits/campaign3to${campaign_id}-1800x1200.v${in_version}.page"
}
