#!/bin/bash
#SBATCH -p GPU-shared
#SBATCH -N 1
#SBATCH -t 48:00:00
#SBATCH --gres=gpu:1

set -x
set -e

db_file=DB_FILE
oltr_dir=OLTR_DIR
rootdir=ROOT_DIR
output_dir=OUTPUT_DIR

# Need to export ENV variable in order find Shuffler interface code from OLTR.
export shuffler_dir=SHUFFLER_DIR

# CONDA_INIT_SCRIPT and CONDA_ENV_DIR will be replaced by their values by submit.sh.
source CONDA_INIT_SCRIPT
conda activate CONDA_ENV_DIR/classifier

# Will generate an error and quit, if does not exist.
ls $db_file

# Create an output directory
mkdir -p "${output_dir}"

# stage_1
time CUDA_VISIBLE_DEVICES=0 python ${oltr_dir}/main_train.py \
    --config ${oltr_dir}/config/stamps/stage_1.py \
    --db_file ${db_file} \
    --rootdir ${rootdir} \
    --output_dir ${output_dir}

# stage_2
time CUDA_VISIBLE_DEVICES=0 python ${oltr_dir}/main_train.py \
    --config ${oltr_dir}/config/stamps/stage_2_meta_embedding.py \
    --db_file ${db_file} \
    --rootdir ${rootdir} \
    --output_dir ${output_dir}
