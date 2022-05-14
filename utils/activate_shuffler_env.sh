#!/bin/bash

# Activates shuffler environment and assigns shuffler_bin env variable.

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

# Init shuffler conda env.
source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}

# Assign shuffler_bin.
export shuffler_bin=${SHUFFLER_DIR}/shuffler.py
