#!/bin/bash

#SBATCH -t 12:00:00
#SBATCH -p GPU-shared
#SBATCH --gres=gpu:GPU_TYPE:1

set -e

# Inputs:
in_db_file=IN_DB_FILE
out_db_file=OUT_DB_FILE
model_path=MODEL_PATH
class_name=CLASS_NAME
# Constants:
root_dir=ROOT_DIR
shuffler_dir=SHUFFLER_DIR
keras_retinanet_dir=KERAS_RETINANET_DIR

source CONDA_INIT_SCRIPT
conda activate CONDA_KERAS_RETINANET_ENV

ls ${in_db_file}
ls ${model_path}
ls ${shuffler_dir}

time python3 \
  ${keras_retinanet_dir}/keras_retinanet/bin/detect.py \
  -i ${in_db_file} \
  -o ${out_db_file} \
  --model_path ${model_path} \
  --coco_category_id_to_name_map "{0: '${class_name}'}" \
  --batch_size 50 \
  --confidence_threshold 0.05 \
  --rootdir ${root_dir}  \
  --shuffler_dir ${shuffler_dir}
