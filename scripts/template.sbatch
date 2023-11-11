#!/bin/bash

#SBATCH -t 5:00:00
#SBATCH -p GPU-shared
#SBATCH --gres=gpu:1

set -x
set -e

# This are replaced with values when using the template.
campaign_id=CAMPAIGN_ID
in_db_name=IN_DB_NAME
folder=FOLDER
databases_dir=DATABASES_DIR
root_dir=ROOT_DIR
labelme_dir=LABELME_DIR
labelme_user=LABELME_USER

source CONDA_INIT_SCRIPT
conda activate CONDA_ENV_DIR/shuffler

cd ${databases_dir}/campaign${campaign_id}

python -m shuffler \
  --rootdir ${root_dir} \
  -i ${in_db_name} \
  -o labelme/${folder}.db \
  filterObjectsSQL \
    --delete \
    --sql "SELECT objectid FROM objects WHERE name LIKE '%page%'" \| \
  expandObjects --expand_fraction 1.0 \| \
  tileObjects \
    --media pictures \
    --image_path "labelme/${folder}-temp" \
    --num_cells_Y 4 \
    --num_cells_X 6 \
    --cell_width 400 \
    --cell_height 400 \
    --split_by_name \
    --image_icon \
    --inter_cell_gap 50 \
    --overwrite \| \
  expandObjects --expand_fraction -0.5 \| \
  exportLabelme \
    --username ${labelme_user} \
    --folder ${folder} \
    --images_dir ${labelme_dir}/campaign${campaign_id}/${folder}/Images \
    --annotations_dir ${labelme_dir}/campaign${campaign_id}/${folder}/Annotations \
    --overwrite

python -m shuffler \
  --rootdir ${root_dir} \
  -i labelme/${folder}.db \
  writeMedia \
    --media video \
    --image_path "labelme/${folder}.avi" \
    --with_objects \
    --with_imageid \
    --overwrite
