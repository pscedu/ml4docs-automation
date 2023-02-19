#!/bin/bash

# Activates shuffler environment.

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

# Init shuffler conda env.
source ${CONDA_INIT_SCRIPT}
conda activate ${CONDA_SHUFFLER_ENV}
