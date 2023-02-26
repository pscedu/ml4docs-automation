#!/bin/bash

# This file contains project-wide variables.

export PROJECT_DIR="/ocean/projects/hum210002p"
export ACCOUNT="hum210002p"

# Bridges-2 specific:
export CONDA_INIT_SCRIPT="/opt/packages/anaconda3/etc/profile.d/conda.sh"
# Directory with all our environments. E.g.: `conda activate ${CONDA_SHUFFLER_ENV}`
export CONDA_ENV_DIR="${PROJECT_DIR}/shared/conda/envs"
export CONDA_SHUFFLER_ENV="${CONDA_ENV_DIR}/shuffler"
export CONDA_KERAS_RETINANET_ENV="${CONDA_ENV_DIR}/keras-retinanet4"
export CONDA_YOLOV5_ENV="${CONDA_ENV_DIR}/yolov5"
export CONDA_OLTR_ENV="${CONDA_ENV_DIR}/OpenLongTailRecognition-OLTR"

# ---- Code ---- #

# Directory with Shuffler code,
export SHUFFLER_DIR="${PROJECT_DIR}/shared/src/ml4docs/shuffler"
# Directory with RetinaNet code.
export KERAS_RETINANET_DIR="${PROJECT_DIR}/shared/src/ml4docs/keras-retinanet"
# Directory with YoloV5 code.
export YOLOV5_DIR="${PROJECT_DIR}/shared/src/ml4docs/yolov5"
# Directory with OLTR code.
export OLTR_DIR="${PROJECT_DIR}/shared/src/ml4docs/OpenLongTailRecognition-OLTR"

# ---- Data ---- #

# All databases reside here.
export DATABASES_DIR="${PROJECT_DIR}/shared/databases"
# Labelme data resides here.
export LABELME_DIR="${PROJECT_DIR}/shared/data"
# Used by Shuffler to determine argument "rootdir".
export ROOT_DIR="${PROJECT_DIR}/shared/data"
# Detection results reside here.
export DETECTION_DIR="${PROJECT_DIR}/shared/detection"
# Detection results reside here.
export CLASSIFICATION_DIR="${PROJECT_DIR}/shared/classification"

export LABELME_USER="tsukeyoka"

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

log_db_version() {
    local campaign_id=$1
    local version=$2
    local text=$3
    echo "v${version}: ${text}
" >> "${DATABASES_DIR}/campaign${campaign_id}/versions.log"
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

