#!/bin/bash

#SBATCH -t 48:00:00
#SBATCH -p GPU-shared
#SBATCH --gres=gpu:GPU_TYPE:NUM_GPUS

set -e

# Inputs:
data_dir=DATA_DIR
batch_size=BATCH_SIZE
epochs=EPOCHS
project_dir=PROJECT_DIR
#img_size=IMG_SIZE
#lr=LEARNING_RATE
no_save_flag=NO_SAVE_FLAG

# Constants:
polygon_yolov5_dir=POLYGON_YOLOV5_DIR

source CONDA_INIT_SCRIPT
conda activate CONDA_POLYGON_YOLOV5_ENV

# Will generate an error and quit, if does not exist.
ls "${data_dir}"
ls "${data_dir}/dataset.yml"
# Start from there, this way avoid writing the full path into dataset.yml
cd ${data_dir}

# Create an output directory
mkdir -p "${project_dir}"

time python3 \
  ${polygon_yolov5_dir}/polygon-yolov5/polygon_train.py \
  --weights '' \
  --cfg "${polygon_yolov5_dir}/polygon-yolov5/models/polygon_stamps_1024.yaml" \
  --hyp "${polygon_yolov5_dir}/polygon-yolov5/data/hyp.scratch.yaml" \
  --data ./dataset.yml \
  --img-size 1024 \
  --multi-scale \
  --epochs=${epochs} \
  --batch-size=${batch_size} \
  --project="${project_dir}" \
  ${no_save_flag} \
  --workers=4 \
  --noautoanchor \
  --polygon

# --weights="${project_dir}/yolov5x.pt" \
