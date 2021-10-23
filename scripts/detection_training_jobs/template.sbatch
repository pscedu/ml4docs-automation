#!/bin/bash

#SBATCH -t 04:00:00
#SBATCH -p GPU-shared
#SBATCH --gres=gpu:GPU_TYPE:NUM_GPUS

set -x
set -e

source CONDA_INIT_SCRIPT
conda activate CONDA_ENV_DIR/keras-retinanet4

experiment_dir=EXPERIMENT_DIR

local_data="$LOCAL/local_data"
local_snapshots="$LOCAL/local_snapshots"
echo "local_data:       ${local_data}"
echo "local_snapshots:  ${local_snapshots}"

mkdir -p ${local_data}

# Copy from Ocean to this machine. "/" is important.
rsync -a SPLIT_DIR/ ${local_data}

echo "rsync command ran."
ls ${local_data}

time KERAS_RETINANET_DIR/keras_retinanet/bin/train.py \
  --batch-size=BATCH_SIZE \
  --lr=LEARNING_RATE \
  --epochs=EPOCHS \
  --steps=STEPS \
  --tensorboard-dir="${experiment_dir}/tensorboard/" \
  --weights="KERAS_RETINANET_DIR/snapshots/resnet50_coco_best_v2.1.0.h5" \
  --snapshot-path="${local_snapshots}" \
  NO_SNAPSHOTS_FLAG \
  MULTI_GPU_OPTION \
  coco "${local_data}"

# Copy from this machien to Ocean. "/" is important.
mkdir -p "${experiment_dir}/snapshots"
rsync -a ${local_snapshots}/ "${experiment_dir}/snapshots"
