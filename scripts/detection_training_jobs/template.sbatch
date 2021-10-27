#!/bin/bash

#SBATCH -t 12:00:00
#SBATCH -p GPU-shared
#SBATCH --gres=gpu:GPU_TYPE:NUM_GPUS

set -x
set -e

source CONDA_INIT_SCRIPT
conda activate CONDA_ENV_DIR/keras-retinanet4

# Copy from Ocean to this machine. 
local_data="$LOCAL/local_data"
echo "local_data:       ${local_data}"
mkdir -p ${local_data}
rsync -a SPLIT_DIR/ ${local_data}  # "/" is important.
echo "rsync command has finished."
ls ${local_data}   # Will trigger exit if folder does not exist.

time KERAS_RETINANET_DIR/keras_retinanet/bin/train.py \
  --batch-size=BATCH_SIZE \
  --lr=LEARNING_RATE \
  --epochs=EPOCHS \
  --steps=STEPS \
  --tensorboard-dir="EXPERIMENT_DIR/tensorboard/" \
  --weights="KERAS_RETINANET_DIR/snapshots/resnet50_coco_best_v2.1.0.h5" \
  --snapshot-path="EXPERIMENT_DIR/snapshots/" \
  NO_SNAPSHOTS_FLAG \
  MULTI_GPU_OPTION \
  coco "${local_data}"
