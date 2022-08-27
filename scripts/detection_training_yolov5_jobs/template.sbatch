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
img_size=IMG_SIZE
no_save_flag=NO_SAVE_FLAG

# Constants:
yolov5_dir=YOLOV5_DIR

source CONDA_INIT_SCRIPT
conda activate CONDA_YOLOV5_ENV

# Will generate an error and quit, if does not exist.
ls "${data_dir}"
ls "${data_dir}/dataset.yml"
# Start from there, this way avoid writing the full path into dataset.yml
cd ${data_dir}

# Create an output directory
mkdir -p "${project_dir}"

time python3 \
  ${yolov5_dir}/train.py \
  --data "./dataset.yml" \
  --img-size=${img_size} \
  --batch-size=${batch_size} \
  --epochs=${epochs} \
  --project="${project_dir}" \
  --weights="${project_dir}/yolov5x.pt" \
  ${no_save_flag} \
  --workers=4
