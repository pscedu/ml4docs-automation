#!/bin/bash
#SBATCH -p GPU-shared
#SBATCH -N 1
#SBATCH -t 48:00:00
#SBATCH --gres=gpu:1

set -x
set -e

# Inputs. PROJECT_DIR and CAMPAIGN_ID will be replaced by their values by submit.sh.
project_dir=PROJECT_DIR
campaign_id=CAMPAIGN_ID
db_file="DATABASES_DIR/campaignCAMPAIGN_ID/crops/campaign3toCAMPAIGN_ID-6Kx4K.v7-croppedStamps.db"

# CONDA_INIT_SCRIPT and CONDA_ENV_DIR will be replaced by their values by submit.sh.
source CONDA_INIT_SCRIPT
conda activate CONDA_ENV_DIR/classifier

# Create an output directory
mkdir -p PROJECT_DIR/shared/classification/campaignCAMPAIGN_ID/models/stamps/inference

# Redirecting log files
export LOGS="PROJECT_DIR/shared/classification/campaignCAMPAIGN_ID/models/stamps/inference"

# <command to run training>
export classes=$(sqlite3 $db_file "SELECT MAX(CAST(value AS INT)) FROM properties WHERE key == 'name_id'")

# sed -i -e "s/\<${training_opt['num_classes']}\>/$classes/g" /ocean/projects/hum180001p/shared/src/ml4docs/mlstamps_oltr/config/stamps/stage_1.py
# sed -i -e "s/\<${training_opt['num_classes']}\>/$classes/g" /ocean/projects/hum180001p/shared/src/ml4docs/mlstamps_oltr/config/stamps/stage_2_meta_embedding.py

# inference

time CUDA_VISIBLE_DEVICES=0 python CLASSIFIER_DIR/inference.py --config CLASSIFIER_DIR/config/stamps/stage_2_meta_embedding.py --test_open \
    --root_dir ROOT_DIR --db_file $db_file --log_dir $LOGS --num_classes $classes --classifier_path CLASSIFIER_DIR

