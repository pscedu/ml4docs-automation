#!/bin/bash

# This file contains project-wide variables.

export PROJECT_DIR="/ocean/projects/hum210002p"
export ACCOUNT="hum210002p"

# Bridges-2 specific:
export CONDA_INIT_SCRIPT="/opt/packages/anaconda3/etc/profile.d/conda.sh"
# Directory with all our environments. E.g.: `conda activate ${CONDA_SHUFFLER_ENV}`
export CONDA_ENV_DIR="${PROJECT_DIR}/shared/conda/envs"
export CONDA_SHUFFLER_ENV="${CONDA_ENV_DIR}/shuffler"
export CONDA_YOLOV5_ENV="${CONDA_ENV_DIR}/yolov5"
export CONDA_OLTR_ENV="${CONDA_ENV_DIR}/OpenLongTailRecognition-OLTR"
export CONDA_POLYGON_YOLOV5_ENV="${CONDA_ENV_DIR}/PolygonObjectDetection"

# ---- Code ---- #

# Directory with Shuffler code,
export SHUFFLER_DIR="${PROJECT_DIR}/shared/src/ml4docs/shuffler"
# Directory with YoloV5 code.
export YOLOV5_DIR="${PROJECT_DIR}/shared/src/ml4docs/yolov5"
# Directory with OLTR code.
export OLTR_DIR="${PROJECT_DIR}/shared/src/ml4docs/OpenLongTailRecognition-OLTR"
# Directory with PolygonYoloV5 code.
export POLYGON_YOLOV5_DIR="${PROJECT_DIR}/shared/src/ml4docs/PolygonObjectDetection"

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

log_db_version() {
    local campaign_id=$1
    local version=$2
    local text=$3
    echo "v${version} $(date): ${text}
" >> "${DATABASES_DIR}/campaign${campaign_id}/versions.log"
}
