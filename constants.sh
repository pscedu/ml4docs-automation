#!/bin/bash

# This file contains project-wide variables.

export PROJECT_DIR="/ocean/projects/hum180001p"
# Needed to run batch jobs.
export ACCOUNT="hum180001p"

# Bridges-2 specific:
export CONDA_INIT_SCRIPT="/opt/packages/anaconda3/etc/profile.d/conda.sh"
# Directory with all our environments. E.g.: `conda activate ${CONDA_ENV_DIR}/shuffler`
export CONDA_ENV_DIR="${PROJECT_DIR}/shared/conda/envs"
export CONDA_SHUFFLER_ENV="${CONDA_ENV_DIR}/shuffler"
export CONDA_KERAS_RETINANET_ENV="${CONDA_ENV_DIR}/keras-retinanet4"
export CONDA_OLTR_ENV="${CONDA_ENV_DIR}/OpenLongTailRecognition-OLTR"

# ---- Code ---- #

# Directory with Shuffler code,
export SHUFFLER_DIR="${PROJECT_DIR}/shared/src/ml4docs/shuffler"
# Directory with RetinaNet code.
export KERAS_RETINANET_DIR="${PROJECT_DIR}/shared/src/ml4docs/keras-retinanet"
# Directory with mlstamps_oltr code.
export OLTR_DIR="${PROJECT_DIR}/shared/src/ml4docs/mlstamps_oltr"

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
