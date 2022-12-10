#!/bin/bash
#SBATCH -t 24:00:00
#SBATCH -p GPU-shared
#SBATCH --gres=gpu:v100-32:1

set -e

train_db_file=TRAIN_DB_FILE
val_db_file=VAL_DB_FILE
oltr_dir=OLTR_DIR
rootdir=ROOT_DIR
shuffler_dir=SHUFFLER_DIR
output_dir=OUTPUT_DIR
config_suffix=CONFIG_SUFFIX
wandb_basename=WANDB_BASENAME
encoding_file=ENCODING_FILE

# CONDA_INIT_SCRIPT and CONDA_ENV_DIR will be replaced by their values by submit.sh.
source CONDA_INIT_SCRIPT
conda activate CONDA_OLTR_ENV

# Will generate an error and quit, if does not exist.
ls ${train_db_file}
ls ${val_db_file}
ls ${encoding_file}

# Need to go to ${oltr_dir}, because many configs use relative paths.
cd ${oltr_dir}
ls "./config/stamps/stage_1${config_suffix}.py"
ls "./config/stamps/stage_2${config_suffix}.py"

# Create an output directory
mkdir -p "${output_dir}/stage1"

# stage_1
time python ./main_train.py \
    --config "./config/stamps/stage_1${config_suffix}.py" \
    --train_db_file ${train_db_file} \
    --val_db_file ${val_db_file} \
    --rootdir ${rootdir} \
    --shuffler_dir ${shuffler_dir} \
    --output_dir "${output_dir}/stage1" \
    --encoding_file ${encoding_file} \
    --wandb_mode online \
    --wandb_name "${wandb_basename}${config_suffix}_stage1"

# Create an output directory
mkdir -p "${output_dir}/stage2"

# stage_2
time python ./main_train.py \
    --config "./config/stamps/stage_2${config_suffix}.py" \
    --train_db_file ${train_db_file} \
    --val_db_file ${val_db_file} \
    --rootdir ${rootdir} \
    --shuffler_dir ${shuffler_dir} \
    --init_weights_dir "${output_dir}/stage1" \
    --output_dir "${output_dir}/stage2" \
    --encoding_file ${encoding_file} \
    --wandb_mode online \
    --wandb_name "${wandb_basename}${config_suffix}_stage2"
