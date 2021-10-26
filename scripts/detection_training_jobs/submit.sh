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
     --set SET_ID
     --run RUN_ID
     --steps_per_epoch STEPS_PER_EPOCH
     --gpu_type GPU_TYPE
     --num_gpus NUM_GPUS
     --dry_run DRY_RUN
     --account ACCOUNT

Example:
  $PROGNAME
     --experiments_path /ocean/projects/hum180001p/results/campaign5/set0/run0/experiment-design.txt
     --split_dir /ocean/projects/hum180001p/data/campaign5/splits/campaign3to5-1800x1200.v2-stamp-masked
     --campaign 5
     --set="-stamp-1800x1200"
     --run 0

Options:
  --experiments_path
      (required) Path to "experiment-design.txt" file. 
                 Use experiment.example.v2.txt in this directory as an example.
  --splits_dir
      (required) Directory with data splits.
                 Example: /ocean/projects/hum180001p/data/campaign5/splits/campaign3to5-1800x1200.v2-stamp-masked
  --campaign
      (required) Id of campaign. Example: 5.
  --set
      (required) Id of set. Example: 3.
  --run
      (required) Id of run. Example: 0.
  --steps_per_epoch
      (optional) Number of steps per epoch. Default is 250.
  --gpu_type
      (optional) GPU type to use. Default: "v100-32".
  --num_gpus
      (optional) Number of GPUs to use. Default: 1.
  --dry_run
      (optional) Enter 1 to NOT submit jobs. Default: 0.
  --account
      (optional) Default: "hum180001p".
  -h|--help
      Print usage and exit.
EO
}

ARGUMENT_LIST=(
    "experiments_path"
    "splits_dir"
    "campaign"
    "set"
    "run"
    "steps_per_epoch"
    "gpu_type"
    "num_gpus"
    "dry_run"
    "account"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
steps_per_epoch=250
gpu_type="v100-32"
num_gpus=1
dry_run=0
account="hum180001p"

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
        --set)
            set_id=$2
            shift 2
            ;;
        --run)
            run_id=$2
            shift 2
            ;;
        --steps_per_epoch)
            steps_per_epoch=$2
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
        --account)
            account=$2
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
  echo "Argument 'set' is required."
  exit 1
fi
if [ -z "$run_id" ]; then
  echo "Argument 'run' is required."
  exit 1
fi

# The end of the parsing code.
################################################################################

# Import all constants. Assumes this file is in scripst/detection_training_jobs.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../../constants.sh

dir_of_this_file=$(dirname $(readlink -f $0))
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

results_dir="${DETECTION_DIR}/campaign${campaign_id}/set${set_id}/run${run_id}"
echo "campaign_id:      $campaign_id"
echo "set_id:           $set_id"
echo "run_id:           $run_id"
echo "results_dir:      $results_dir"
echo "splits_dir:       $splits_dir"
echo "steps_per_epoch:  $steps_per_epoch"
echo "gpu_type:         $gpu_type"
echo "num_gpus:         $num_gpus"
echo "account:          $account"

mkdir -p ${results_dir}
status=$?
if [ ${status} -ne 0 ]; then
  echo "Could not create directory '${results_dir}'"
  exit ${status}
fi

for line in $(cat ${experiments_path})
do
    IFS=';' # Delimiter
    read -ra ADDR <<< "$line" # line is read into an array as tokens separated by IFS
    echo "Line: ${ADDR[@]}"
    if [[ ${ADDR[0]} == "#" ]]; then
        echo "This line is a comment. Skip."
        continue
    fi

    HYPER_N="${ADDR[0]}"
    SPLIT="${ADDR[1]}"
    BATCH_SIZE="${ADDR[2]}"
    LEARNING_RATE="${ADDR[3]}"
    EPOCHS="${ADDR[4]}"
    SAVE_SNAPSHOTS="${ADDR[5]}"
    STEPS=${steps_per_epoch}
    if [ ${SAVE_SNAPSHOTS} == "0" ]; then
        NO_SNAPSHOTS_FLAG="--no-snapshots"
    else
        NO_SNAPSHOTS_FLAG=""
    fi

    # In case of multiple GPUs, we need to provide some extra arguments.
    if [ ${num_gpus} -gt 1 ]; then
      echo "Going to run in the multi-gpu mode."
      num_gpu_options="--multi-gpu ${num_gpus} --multi-gpu-force"
    else
      num_gpu_options=""
    fi
    
    split_dir=$splits_dir/$SPLIT
    if [ ! -d "$split_dir" ]; then
        echo "Directory with a split does not exist at '$split_dir'"
        exit 1
    fi
    if [ ! -d "$split_dir/images/train2017" ]; then
        echo "Warning: Directory with TRAINING images does not exist at '$split_dir/images/train2017'"
        exit 1
    fi
    if [ ! -d "$split_dir/images/val2017" ]; then
        echo "Warning: Directory with VALIDATION images does not exist at '$split_dir/images/val2017'"
        exit 1
    fi
    if [ ! -f "$split_dir/annotations/instances_train2017.json" ]; then
        echo "Warning: File with TRAINING annotations does not exist at '$split_dir/annotations/instances_train2017.json'"
        exit 1
    fi
    if [ ! -f "$split_dir/annotations/instances_val2017.json" ]; then
        echo "Warning: File with VALIDATION annotations does not exist at '$split_dir/annotations/instances_val2017.json'"
        exit 1
    fi

    experiment_result_dir="${results_dir}/results/hyper${HYPER_N}"
    mkdir -p ${results_dir}/results/hyper${HYPER_N}/snapshots && \
    mkdir -p ${results_dir}/results/hyper${HYPER_N}/tensorboard && \
    mkdir -p ${results_dir}/input/hyper${HYPER_N}

    sed \
      -e "s|SPLIT_DIR|$split_dir|g" \
      -e "s|BATCH_SIZE|${BATCH_SIZE}|g" \
      -e "s|LEARNING_RATE|${LEARNING_RATE}|g" \
      -e "s|EPOCHS|${EPOCHS}|g" \
      -e "s|STEPS|${STEPS}|g" \
      -e "s|EXPERIMENT_DIR|${experiment_result_dir}|g" \
      -e "s|NO_SNAPSHOTS_FLAG|${NO_SNAPSHOTS_FLAG}|g" \
      -e "s|CONDA_INIT_SCRIPT|${CONDA_INIT_SCRIPT}|g" \
      -e "s|CONDA_ENV_DIR|${CONDA_ENV_DIR}|g" \
      -e "s|KERAS_RETINANET_DIR|${KERAS_RETINANET_DIR}|g" \
      -e "s|DETECTION_DIR|${DETECTION_DIR}|g" \
      -e "s|GPU_TYPE|${gpu_type}|g" \
      -e "s|NUM_GPUS|${num_gpus}|g" \
      -e "s|MULTI_GPU_OPTION|${num_gpu_options}|g" \
      ${template_path} > "${results_dir}/input/hyper${HYPER_N}/hyper${HYPER_N}.sbatch"
    status=$?
    if [ ${status} -ne 0 ]; then
      echo "Failed to use the template from '${template_path}'"
      exit ${status}
    fi

    if [ ${dry_run} == "0" ]; then
      JID=$(sbatch -A ${account} \
            --output="${results_dir}/results/hyper${HYPER_N}/hyper${HYPER_N}.out" \
            --error="${results_dir}/results/hyper${HYPER_N}/hyper${HYPER_N}.err" \
            "${results_dir}/input/hyper${HYPER_N}/hyper${HYPER_N}.sbatch")
      
      echo $JID
      JOB_ID=${JID##* }
      touch "${results_dir}/job_ids.txt"
      echo `date`" "${JOB_ID} >> "${results_dir}/job_ids.txt"
    fi

    IFS=' ' # reset to default value after usage
done
