#!/bin/bash

#SBATCH -t 12:00:00
#SBATCH -p GPU-shared
#SBATCH --gres=gpu:GPU_TYPE:NUM_GPUS

set -e

# Inputs:
train_db_file=TRAIN_DB_FILE
val_db_file=VAL_DB_FILE
batch_size=BATCH_SIZE
learning_rate=LEARNING_RATE
epochs=EPOCHS
steps=STEPS
no_snapshots_flag="NO_SNAPSHOTS_FLAG"
multi_gpu_option="MULTI_GPU_OPTION"
# Constants:
root_dir=ROOT_DIR
shuffler_dir=SHUFFLER_DIR
keras_retinanet_dir=KERAS_RETINANET_DIR

source CONDA_INIT_SCRIPT
conda activate CONDA_KERAS_RETINANET_ENV

time python3 \
  ${keras_retinanet_dir}/keras_retinanet/bin/train.py \
  --batch-size=${batch_size} \
  --lr=${learning_rate} \
  --epochs=${epochs} \
  --steps=${steps} \
  --tensorboard-dir="EXPERIMENT_DIR/tensorboard/" \
  --weights="KERAS_RETINANET_DIR/snapshots/resnet50_coco_best_v2.1.0.h5" \
  --snapshot-path="EXPERIMENT_DIR/snapshots/" \
  ${no_snapshots_flag} \
  ${multi_gpu_option} \
  shuffler \
  --train_db_file ${train_db_file} \
  --val_db_file ${val_db_file} \
  --rootdir ${root_dir} \
  --shuffler_dir ${shuffler_dir}
