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
yolov5_dir=YOLOV5_DIR

source CONDA_INIT_SCRIPT
conda activate CONDA_YOLOV5_ENV

ls ${in_db_file}
ls ${model_path}

time python3 ${yolov5_dir}/detect_shuffler.py \
  -i ${in_db_file} \
  -o ${out_db_file} \
  --coco_category_id_to_name_map "{0: '${class_name}'}" \
  --batch_size 50 \
  --weights ${model_path} \
  --imgsz 1824 \
  --conf-thres 0.05 \
  --rootdir ${root_dir}
