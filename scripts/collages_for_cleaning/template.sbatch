#!/bin/bash
#SBATCH -p GPU-shared
#SBATCH -t 5:00:00
#SBATCH --gres=gpu:volta16:1
set -x

# This are replaced with values when using the template.
project_dir=PROJECT_DIR
campaign_id=CAMPAIGN_ID
db_name=DB_NAME
folder=FOLDER

shuffler_bin=${project_dir}/shared/src/shuffler/shuffler.py
source /opt/packages/anaconda/anaconda3-5.1.0/bin/activate \
  ${project_dir}/shared/conda/envs/shuffler
${shuffler_bin} -h

cd ${project_dir}/etoropov/campaign${campaign_id}

mkdir -p labelme/${folder}

${shuffler_bin} \
  --rootdir ${project_dir}/shared/data \
  -i ${db_name} \
  -o labelme/${folder}.db \
  filterObjectsSQL \
    --sql "SELECT objectid FROM objects WHERE name LIKE '%page%'" \| \
  expandObjects --expand_perc 1.0 \| \
  tileObjects \
    --media pictures \
    --image_path "labelme/${folder}-temp" \
    --num_cells_Y 5 \
    --num_cells_X 5 \
    --cell_width 400 \
    --cell_height 400 \
    --split_by_name \
    --image_icon \
    --inter_cell_gap 50 \
    --overwrite \| \
  expandObjects --expand_perc -0.5 \| \
  exportLabelme \
    --username tsukeyoka \
    --folder ${folder} \
    --images_dir labelme/${folder}/Images \
    --annotations_dir labelme/${folder}/Annotations \
    --overwrite

${shuffler_bin} \
  --rootdir ${project_dir}/shared/data \
  -i labelme/${folder}.db \
  writeMedia \
    --media video \
    --image_path "labelme/${folder}.avi" \
    --with_objects \
    --with_imageid \
    --overwrite
