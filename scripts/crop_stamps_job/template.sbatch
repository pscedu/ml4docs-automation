#!/bin/bash

#SBATCH -t 08:00:00
#SBATCH -p GPU-shared
#SBATCH --gres=gpu:1

set -x
set -e

# Inputs:
campaign_id=CAMPAIGN_ID
in_db_file=IN_DB_FILE
out_cropped_db_file=OUT_CROPPED_DB_FILE
size=SIZE
# Constants:
root_dir=ROOT_DIR
shuffler_dir=SHUFFLER_DIR

source CONDA_INIT_SCRIPT
conda activate CONDA_SHUFFLER_ENV

# Make a directory for cropped db and images.
mkdir -p $(dirname ${out_cropped_db_file})

# Split extension to make a folder name.
out_cropped_db_filestem="${out_cropped_db_file%.*}"

# Either resize or keep, depending on "size" arg.
if [ -z ${size} ]; then
  edges_clause="--image_path ${out_cropped_db_filestem} --edges original"
else
  edges_clause="--image_path ${out_cropped_db_filestem}-${size}x${size} --edges distort --target_width ${size} --target_height ${size}"
fi

${shuffler_dir}/shuffler.py \
  --rootdir ${root_dir} \
  -i ${in_db_file} \
  -o ${out_cropped_db_file} \
  cropObjects \
    --where_object "objects.name NOT LIKE '%page%' AND objects.name != '??'" \
    --media "pictures" \
    --overwrite \
    ${edges_clause}
