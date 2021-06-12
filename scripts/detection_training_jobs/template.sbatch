#!/bin/bash

#SBATCH -t 08:00:00
#SBATCH -p GPU-AI
#SBATCH --gres=gpu:volta16:1

project_dir=/ocean/projects/hum180001p

export MODEL_HOME=${project_dir}/src/keras-retinanet/
source /opt/packages/anaconda/anaconda3-5.1.0/bin/activate ${project_dir}/conda/envs/keras-retinanet4
cd $MODEL_HOME

time keras_retinanet/bin/train.py --batch-size=BATCH_SIZE --lr=LEARNING_RATE --epochs=EPOCHS --steps=STEPS NO_SNAPSHOTS_FLAG \
--tensorboard-dir=${project_dir}/detection/campaignCAMPAIGN_ID/setSET_ID/runRUN_ID/results/hyperHYPER_N/tensorboard/ \
--weights snapshots/resnet50_coco_best_v2.1.0.h5 \
--snapshot-path ${project_dir}/detection/campaignCAMPAIGN_ID/setSET_ID/runRUN_ID/results/hyperHYPER_N/snapshots \
coco SPLIT_DIR
