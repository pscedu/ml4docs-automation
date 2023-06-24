#!/bin/bash

set -e

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
This scripts submits a set of experiments for keras-retinanet.
A directory is created for each experiment, and then an sbatch is submitted.
 
The script can be run in dry-run mode without submitting jobs.

Usage:
  $PROGNAME
     --experiments_path
     --split_dir
     --campaign CAMPAIGN_ID
     --set_id SET_ID
     --run_id RUN_ID
     --img_size IMG_SIZE
     --gpu_type GPU_TYPE
     --num_gpus NUM_GPUS
     --dry_run DRY_RUN

Example:
  $PROGNAME
     --experiments_path /ocean/projects/hum180001p/results/campaign5/set0/run0/experiment-design.txt
     --split_dir /ocean/projects/hum180001p/data/campaign5/splits/campaign3to5-1800x1200.v2-stamp-masked
     --campaign 5
     --set="set-stamp-1800x1200"
     --run_id 0

Options:
  --experiments_path
      (required) Path to "experiment-design.txt" file. 
  --splits_dir
      (required) Directory with data splits.
  --campaign
      (required) Id of campaign. Example: 5.
  --set_id
      (required) Id of set. Example: 3.
  --run_id
      (required) Id of run. Example: 0.
  --img_size
      (optional) The size longer image side after resizing. Default is 1824.
  --gpu_type
      (optional) GPU type to use. Default: "v100-32".
  --num_gpus
      (optional) Number of GPUs to use. Default: 1.
  --dry_run
      (optional) Enter 1 to NOT submit jobs. Default: 0.
  -h|--help
      Print usage and exit.
EO
}

ARGUMENT_LIST=(
    "experiments_path"
    "splits_dir"
    "campaign"
    "set_id"
    "run_id"
    "img_size"
    "gpu_type"
    "num_gpus"
    "dry_run"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
img_size=1824
gpu_type="v100-32"
num_gpus=1
dry_run=0

eval set --$opts

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --experiments_path)
            experiments_path=$2
            shift 2
            ;;
        --splits_dir)
            splits_dir=$2
            shift 2
            ;;
        --campaign)
            campaign_id=$2
            shift 2
            ;;
        --set_id)
            set_id=$2
            shift 2
            ;;
        --run_id)
            run_id=$2
            shift 2
            ;;
        --img_size)
            img_size=$2
            shift 2
            ;;
        --gpu_type)
            gpu_type=$2
            shift 2
            ;;
        --num_gpus)
            num_gpus=$2
            shift 2
            ;;
        --dry_run)
            dry_run=$2
            shift 2
            ;;
        --) # No more arguments
            shift
            break
            ;;
        *)
            echo "Arg '$1' is not supported."
            exit 1
            ;;
    esac
done

# Check required arguments.
if [ -z "$experiments_path" ]; then
  echo "Argument 'experiments_path' is required."
  exit 1
fi
if [ -z "$splits_dir" ]; then
  echo "Argument 'splits_dir' is required."
  exit 1
fi
if [ -z "$campaign_id" ]; then
  echo "Argument 'campaign' is required."
  exit 1
fi
if [ -z "$set_id" ]; then
  echo "Argument 'set_id' is required."
  exit 1
fi
if [ -z "$run_id" ]; then
  echo "Argument 'run_id' is required."
  exit 1
fi

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../../constants.sh
source ${dir_of_this_file}/../../path_generator.sh

# Will contain hyperparameter folders.
run_dir=$(get_detection_run_dir ${campaign_id} ${set_id} ${run_id})

template_path="${dir_of_this_file}/template.sbatch"
if [ ! -f "$template_path" ]; then
    echo "Job template does not exist at '$template_path'"
    exit 1
fi

if [ ! -f "$experiments_path" ]; then
    echo "File '$experiments_path' does not exist."
    exit 1
fi

if [ ! -d "$splits_dir" ]; then
    echo "Directory with splits does not exist at '$splits_dir'"
    exit 1
fi

echo "run_dir:          ${run_dir}"
echo "experiments_path: ${experiments_path}"
echo "splits_dir:       ${splits_dir}"
echo "campaign_id:      ${campaign_id}"
echo "set_id:           ${set_id}"
echo "run_id:           ${run_id}"
echo "dry_run:          ${dry_run}"
echo "img_size:         ${img_size}"
echo "gpu_type:         ${gpu_type}"
echo "num_gpus:         ${num_gpus}"

cat ${experiments_path} | while read line || [[ -n $line ]];
do
    echo "Line: ${line}"
    if [[ "${line}" == "" ]]; then
        echo "Skipping an empty line."
        continue
    fi
    if [[ ${line} == \#* ]]; then
        echo "This line is a comment. Skip."
        continue
    fi

    IFS=';' # Delimiter
    read -ra ADDR <<< "$line" # line is read into an array as tokens separated by IFS

    HYPER_N="${ADDR[0]}"
    SPLIT="${ADDR[1]}"
    BATCH_SIZE="${ADDR[2]}"
    LEARNING_RATE="${ADDR[3]}"
    EPOCHS="${ADDR[4]}"
    SAVE_SNAPSHOTS="${ADDR[5]}"
    if [ ${SAVE_SNAPSHOTS} == "0" ]; then
        NO_SAVE_FLAG="--nosave"
    else
        NO_SAVE_FLAG=""
    fi

    # # In case of multiple GPUs, we need to provide some extra arguments.
    # if [ ${num_gpus} -gt 1 ]; then
    #   echo "Going to run in the multi-gpu mode."
    #   num_gpu_options="--multi-gpu ${num_gpus} --multi-gpu-force"
    # else
    #   num_gpu_options=""
    # fi
    
    split_dir=$splits_dir/$SPLIT
    if [ ! -d "$split_dir" ]; then
        echo "Directory with a split does not exist at '$split_dir'"
        exit 1
    fi
    
    hyper_dir="${run_dir}/hyper${HYPER_N}"
    mkdir -p ${hyper_dir}

    # Stem of the batch job (without extension).
    batch_job_dir="${hyper_dir}/batch_jobs"
    mkdir -p "${batch_job_dir}"
    batch_job_path_stem="${batch_job_dir}/train_detector_$(date +%Y-%m-%d_%H-%M)"

    sed \
      -e "s|DATA_DIR|${split_dir}|g" \
      -e "s|BATCH_SIZE|${BATCH_SIZE}|g" \
      -e "s|LEARNING_RATE|${LEARNING_RATE}|g" \
      -e "s|EPOCHS|${EPOCHS}|g" \
      -e "s|IMG_SIZE|${img_size}|g" \
      -e "s|PROJECT_DIR|${hyper_dir}|g" \
      -e "s|NO_SAVE_FLAG|${NO_SAVE_FLAG}|g" \
      -e "s|CONDA_INIT_SCRIPT|${CONDA_INIT_SCRIPT}|g" \
      -e "s|CONDA_POLYGON_YOLOV5_ENV|${CONDA_POLYGON_YOLOV5_ENV}|g" \
      -e "s|POLYGON_YOLOV5_DIR|${POLYGON_YOLOV5_DIR}|g" \
      -e "s|DETECTION_DIR|${DETECTION_DIR}|g" \
      -e "s|GPU_TYPE|${gpu_type}|g" \
      -e "s|NUM_GPUS|${num_gpus}|g" \
      ${template_path} > "${batch_job_path_stem}.sbatch"
    status=$?
    if [ ${status} -ne 0 ]; then
        echo "Failed to use the template from '${template_path}'"
        exit ${status}
    fi

    echo "Wrote a job file to '${batch_job_path_stem}.sbatch'."
    if [ ${dry_run} == "0" ]; then
        JID=$(sbatch -A ${ACCOUNT} \
            --output="${batch_job_path_stem}.out" \
            --error="${batch_job_path_stem}.err" \
            "${batch_job_path_stem}.sbatch")
        echo $JID
        JOB_ID=${JID##* }
        touch "${batch_job_dir}/job_ids.txt"
        echo `date`" "${JOB_ID} >> "${batch_job_dir}/job_ids.txt"
    fi

    IFS=' ' # reset to default value after usage
done
