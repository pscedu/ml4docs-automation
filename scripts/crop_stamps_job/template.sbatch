#!/bin/bash

#SBATCH -t 08:00:00
#SBATCH -p GPU-shared
#SBATCH --gres=gpu:1

set -x
set -e

# Inputs:
campaign_id=CAMPAIGN_ID
db_stem=DB_STEM
size=SIZE
# Constants:
databases_dir=DATABASES_DIR
root_dir=ROOT_DIR
shuffler_dir=SHUFFLER_DIR

source CONDA_INIT_SCRIPT
conda activate CONDA_ENV_DIR/shuffler

cd "${databases_dir}/campaign${campaign_id}"
mkdir -p crops

# Either resize or keep, depending on "size" arg.
if [ -n ${size} ]; then
  edges_clause="--image_path crops/${db_stem}-croppedStamps --edges original"
else
  edges_clause="--image_path crops/${db_stem}-croppedStamps-${size}x${size} --edges distort --target_width ${size} --target_height ${size}"
fi

${shuffler_dir}/shuffler.py \
  --rootdir ${root_dir} \
  -i "${db_stem}.db" \
  -o "crops/${db_stem}-croppedStamps.db" \
  cropObjects \
    --where_object "objects.name NOT LIKE '%page%' AND objects.name != '??'" \
    --media "pictures" \
    --overwrite \
    ${edges_clause}
