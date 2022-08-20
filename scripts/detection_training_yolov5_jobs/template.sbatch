#!/bin/bash

#SBATCH -t 48:00:00
#SBATCH -p GPU-shared
#SBATCH --gres=gpu:GPU_TYPE:NUM_GPUS

set -e

# Inputs:
train_db_file=TRAIN_DB_FILE
val_db_file=VAL_DB_FILE
batch_size=BATCH_SIZE
epochs=EPOCHS
project_dir=PROJECT_DIR
img_size=IMG_SIZE
no_save_flag=NO_SAVE_FLAG

# Constants:
root_dir=ROOT_DIR
shuffler_dir=SHUFFLER_DIR
yolov5_dir=YOLOV5_DIR

source CONDA_INIT_SCRIPT
conda activate CONDA_YOLOV5_ENV

# Will generate an error and quit, if does not exist.
ls ${train_db_file}
ls ${val_db_file}

# Create an output directory
mkdir -p "${project_dir}"

time python3 \
  ${yolov5_dir}/train_shuffler.py \
  --train_db_file ${train_db_file} \
  --val_db_file ${val_db_file} \
  --rootdir ${root_dir} \
  --img-size=${img_size} \
  --batch-size=${batch_size} \
  --epochs=${epochs} \
  --project=${project_dir} \
  --weights="${project_dir}/yolov5x.pt" \
  --workers=4 \
  ${no_save_flag} \
  --shuffler_dir=${shuffler_dir}
