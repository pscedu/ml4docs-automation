#!/bin/bash
#SBATCH -t 5:00:00

set -x

# Inputs:
project_dir=PROJECT_DIR
db_stem=DB_STEM
campaign_id=CAMPAIGN_ID
size=SIZE

shuffler_bin=${project_dir}/shared/src/shuffler/shuffler.py

source /opt/packages/anaconda/anaconda3-5.1.0/bin/activate \
       /ocean/projects/hum180001p/shared/conda/envs/shuffler

cd "${project_dir}/etoropov/campaign${campaign_id}"
mkdir -p crops

# Either resize or keep, depending on "size" arg.
if [ -n ${size} ]; then
  edges_clause="--image_path crops/${db_stem}-croppedStamps --edges original"
else
  edges_clause="--image_path crops/${db_stem}-croppedStamps-${size}x${size} --edges distort --target_width ${size} --target_height ${size}"
fi

${shuffler_bin} \
  --rootdir "${project_dir}/shared/data" \
  -i "${db_stem}.db" \
  -o "crops/${db_stem}-croppedStamps.db" \
  cropObjects \
    --where_object "objects.name NOT LIKE '%page%' AND objects.name != '??'" \
    --media "pictures" \
    --overwrite \
    ${edges_clause}

conda deactivate


