#!/bin/bash
#SBATCH -p GPU-shared
#SBATCH -N 1
#SBATCH -t 2:00:00
#SBATCH --gres=gpu:GPU_TYPE:1

set -e

# Inputs.
pel_dir=PEL_DIR
in_db_file=IN_DB_FILE
out_db_file=OUT_DB_FILE
encoding_file=ENCODING_FILE
model_dir=MODEL_DIR
rootdir=ROOT_DIR

# CONDA_INIT_SCRIPT and CONDA_ENV_DIR will be replaced by their values by submit.sh.
source CONDA_INIT_SCRIPT
conda activate CONDA_PEL_ENV

# Will generate an error and quit, if does not exist.
ls ${in_db_file}
ls ${model_dir}
ls ${encoding_file}

cd ${pel_dir}

# inference
time python ./main_inference.py \
    --out_db_file "${out_db_file}" \
    -m clip_vit_b16_peft \
    test_db_file "${in_db_file}" \
    encoding_file "${encoding_file}" \
    model_dir "${model_dir}" \
    rootdir "${rootdir}" \
    num_workers 1
