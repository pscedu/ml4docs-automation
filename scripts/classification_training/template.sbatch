#!/bin/bash
#SBATCH -t 24:00:00
#SBATCH -p GPU-shared
#SBATCH --gres=gpu:v100-32:1

set -e

db_file=DB_FILE
oltr_dir=OLTR_DIR
rootdir=ROOT_DIR
shuffler_dir=SHUFFLER_DIR
output_dir=OUTPUT_DIR

# CONDA_INIT_SCRIPT and CONDA_ENV_DIR will be replaced by their values by submit.sh.
source CONDA_INIT_SCRIPT
conda activate CONDA_OLTR_ENV

# Will generate an error and quit, if does not exist.
ls $db_file

# Create an output directory
mkdir -p "${output_dir}"

# Need to go to ${oltr_dir}, because many configs use relative paths.
cd ${oltr_dir}

# stage_1
time python ./main_train.py \
    --config ./config/stamps/stage_1.py \
    --db_file ${db_file} \
    --rootdir ${rootdir} \
    --shuffler_dir ${shuffler_dir} \
    --output_dir "${output_dir}/stage1"

# stage_2
time python ./main_train.py \
    --config ./config/stamps/stage_2.py \
    --db_file ${db_file} \
    --rootdir ${rootdir} \
    --shuffler_dir ${shuffler_dir} \
    --init_weights_dir "${output_dir}/stage1" \
    --output_dir "${output_dir}/stage2"
