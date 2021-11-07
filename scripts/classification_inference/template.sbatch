#!/bin/bash
#SBATCH -p GPU-shared
#SBATCH -N 1
#SBATCH -t 48:00:00
#SBATCH --gres=gpu:1

set -x
set -e

# Inputs. PROJECT_DIR and CAMPAIGN_ID will be replaced by their values by submit.sh.
classification_dir=CLASSIFICATION_DIR
campaign_id=CAMPAIGN_ID
db_file=DB_FILE
encoding_json_file=ENCODING_JSON_FILE
oltr_dir=OLTR_DIR
rootdir=ROOT_DIR
shuffler_dir=SHUFFLER_DIR

# CONDA_INIT_SCRIPT and CONDA_ENV_DIR will be replaced by their values by submit.sh.
source CONDA_INIT_SCRIPT
conda activate CONDA_OLTR_ENV

# Will generate an error and quit, if does not exist.
ls $db_file
ls $encoding_json_file

# Create an output directory.
mkdir -p ${output_dir}

# inference
time python ${oltr_dir}/main_inference.py \
    --config ${oltr_dir}/config/stamps/stage_2_meta_embedding.py \
    --db_file ${db_file} \
    --encoding_json_file ${encoding_json_file} \
    --rootdir ${rootdir} \
    --shuffler_dir ${shuffler_dir} \
    --log_dir ${output_dir}
