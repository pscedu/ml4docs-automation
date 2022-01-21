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
experiment_dir=EXPERIMENT_DIR
img_size=IMG_SIZE
# Constants:
root_dir=ROOT_DIR
shuffler_dir=SHUFFLER_DIR
yolov5_dir=YOLOV5_DIR

source CONDA_INIT_SCRIPT
conda activate CONDA_YOLOV5_ENV

time python3 \
  ${yolov5_dir}/train_shuffler.py \
  --img_size=${img_size} \
  --batch=${batch_size} \
  --epochs=${epochs} \
  --weights="yolov5x.pt" \
  --experiment_dir ${experiment_dir}
  ${multi_gpu_option} \
  --train_db_file ${train_db_file} \
  --val_db_file ${val_db_file} \
  --rootdir ${root_dir} \
  --shuffler_dir ${shuffler_dir}
