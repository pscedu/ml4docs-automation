#!/bin/bash
#SBATCH -p GPU-shared
#SBATCH -N 1
#SBATCH -t 24:00:00
#SBATCH --gres=gpu:GPU_TYPE:4

set -e

pel_dir=PEL_DIR
train_db_file=TRAIN_DB_FILE
val_db_file=VAL_DB_FILE
rootdir=ROOT_DIR
output_dir=OUTPUT_DIR
encoding_file=ENCODING_FILE
num_epochs=NUM_EPOCHS

# CONDA_INIT_SCRIPT and CONDA_ENV_DIR will be replaced by their values by submit.sh.
source CONDA_INIT_SCRIPT
conda activate CONDA_PEL_ENV

# Will generate an error and quit, if does not exist.
ls ${train_db_file}
ls ${val_db_file}
ls ${encoding_file}

cd ${pel_dir}

# Create an output directory
mkdir -p "${output_dir}"

time python ./main.py \
    -m clip_vit_b16_peft \
    train_db_file "${train_db_file}" \
    test_db_file "${val_db_file}" \
    encoding_file "${encoding_file}" \
    rootdir "${rootdir}" \
    output_dir "${output_dir}" \
    num_workers 4 \
    num_epochs "${num_epochs}"
