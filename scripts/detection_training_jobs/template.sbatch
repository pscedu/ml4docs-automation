#!/bin/bash

#SBATCH -t 08:00:00
#SBATCH -p GPU-shared
#SBATCH --gres=gpu:1

source CONDA_INIT_SCRIPT
conda activate CONDA_ENV_DIR/keras-retinanet4

time KERAS_RETINANET_DIR/keras_retinanet/bin/train.py \
  --batch-size=BATCH_SIZE \
  --lr=LEARNING_RATE \
  --epochs=EPOCHS \
  --steps=STEPS NO_SNAPSHOTS_FLAG \
  --tensorboard-dir=DETECTION_DIR/campaignCAMPAIGN_ID/setSET_ID/runRUN_ID/results/hyperHYPER_N/tensorboard/ \
  --weights=KERAS_RETINANET_DIR/snapshots/resnet50_coco_best_v2.1.0.h5 \
  --snapshot-path=DETECTION_DIR/campaignCAMPAIGN_ID/setSET_ID/runRUN_ID/results/hyperHYPER_N/snapshots \
  coco SPLIT_DIR
