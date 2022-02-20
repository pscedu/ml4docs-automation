#!/bin/bash

# This file contains project-wide variables.

export PROJECT_DIR="/ocean/projects/hum180001p"
export ACCOUNT="hum210002p"

# Bridges-2 specific:
export CONDA_INIT_SCRIPT="/opt/packages/anaconda3/etc/profile.d/conda.sh"
# Directory with all our environments. E.g.: `conda activate ${CONDA_ENV_DIR}/shuffler`
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
