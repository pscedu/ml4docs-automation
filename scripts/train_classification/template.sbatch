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
db_file=DB_FILE
classifier_dir=CLASSIFIER_DIR
root_dir=ROOT_DIR

# CONDA_INIT_SCRIPT and CONDA_ENV_DIR will be replaced by their values by submit.sh.
source CONDA_INIT_SCRIPT
conda activate CONDA_ENV_DIR/classifier

ls $db_file  # Will generate an error and quit, if does not exist.
num_classes=$(sqlite3 $db_file "SELECT MAX(CAST(value AS INT)) + 1 FROM properties WHERE key == 'name_id'")

# Create an output directory
mkdir -p "${project_dir}/shared/classification/campaign${campaign_id}/models/stamps"

# Redirecting log files
export logs="${project_dir}/shared/classification/campaign${campaign_id}/models/stamps"

# stage_1
time CUDA_VISIBLE_DEVICES=0 python ${classifier_dir}/main_shuffler.py --config ${classifier_dir}/config/stamps/stage_1.py \
    --root_dir ${root_dir} --db_file ${db_file} --log_dir ${logs} --num_classes ${num_classes} --classifier_path ${classifier_dir}

# stage_2
time CUDA_VISIBLE_DEVICES=0 python ${classifier_dir}/main_shuffler.py --config ${classifier_dir}/config/stamps/stage_2_meta_embedding.py \
    --root_dir ${root_dir} --db_file ${db_file} --log_dir ${logs} --num_classes ${num_classes} --classifier_path ${classifier_dir}

