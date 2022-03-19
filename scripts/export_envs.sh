# This script would update yml files for each used en
source constants.sh
source ${CONDA_INIT_SCRIPT}

for env_name in "CONDA_SHUFFLER_ENV" "CONDA_KERAS_RETINANET_ENV" "CONDA_YOLOV5_ENV" "CONDA_OLTR_ENV"
do
  env_value=$(eval "echo \${$env_name}")
  conda activate ${env_value}
  conda env export --no-builds -p ${env_value} > "envs/${env_name}.yml"
  conda deactivate
done
