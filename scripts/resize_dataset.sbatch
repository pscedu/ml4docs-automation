#!/bin/bash
#SBATCH -N 1
#SBATCH --time=10:00:00
#SBATCH --cpus-per-task=20

# 
# This script resizes the original dataset to the target 1800x1200 size,
# while keeping the original folder structure.
#
# It only had to be used ONCE, and is here only for the reference.
#

set -x 

export ORIGINAL_DIR=/ocean/projects/hum180001p/shared/data/original_dataset
export TARGET_DIR=/ocean/projects/hum180001p/shared/1800x1200
export NUM_THREADS=20

mkdir -p ${TARGET_DIR}

cd ${ORIGINAL_DIR}

# Copy a subfolder to the target directory.
ls | xargs -I {} -P ${NUM_THREADS} -d $'\n' bash -c 'cp -r "{}" "$TARGET_DIR"'

# Resize the directory.
ls | xargs -I {} -P ${NUM_THREADS} -d $'\n' bash -c 'mogrify -resize 1800x1200 "$TARGET_DIR/{}"/*.JPG'

