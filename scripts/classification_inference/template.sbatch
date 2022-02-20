#!/bin/bash
#SBATCH -p GPU-shared
#SBATCH -N 1
#SBATCH -t 48:00:00
#SBATCH --gres=gpu:GPU_TYPE:1

set -e

# Inputs. PROJECT_DIR and CAMPAIGN_ID will be replaced by their values by submit.sh.
in_db_file=IN_DB_FILE
out_db_file=OUT_DB_FILE
encoding_file=ENCODING_FILE
oltr_dir=OLTR_DIR
model_dir=MODEL_DIR
rootdir=ROOT_DIR
shuffler_dir=SHUFFLER_DIR
config_suffix=CONFIG_SUFFIX

# CONDA_INIT_SCRIPT and CONDA_ENV_DIR will be replaced by their values by submit.sh.
source CONDA_INIT_SCRIPT
conda activate CONDA_OLTR_ENV

# Will generate an error and quit, if does not exist.
ls ${in_db_file}
ls ${model_dir}
ls ${encoding_file}

# Need to go to ${oltr_dir}, because many configs use relative paths.
cd ${oltr_dir}
ls "./config/stamps/stage_2${config_suffix}.py"

# inference
time python ./main_inference.py \
    --config "./config/stamps/stage_2${config_suffix}.py" \
    --in_db_file ${in_db_file} \
    --out_db_file ${out_db_file} \
    --encoding_file ${encoding_file} \
    --weights_dir "${model_dir}/stage2" \
    --rootdir ${rootdir} \
    --shuffler_dir ${shuffler_dir}
