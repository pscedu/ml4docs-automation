#!/bin/bash

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
     --results_root_dir RESULTS_ROOT_DIR
     --steps_per_epoch STEPS_PER_EPOCH
     --version VERSION
     --dry_run DRY_RUN

Example:
  $PROGNAME
     --experiments_path /pylon5/hm5fp1p/results/campaign5/set0/run0/experiment-design-full.txt
     --split_dir /pylon5/hm5fp1p/data/campaign5/splits/campaign3to5-1800x1200.v2-stamp-masked
     --campaign 5
     --set 0
     --run 0

Options:
  --experiments_path
      (required) Path to "experiment-design-full.txt" file. 
                 Use an example in this directory and modify it.
  --splits_dir
      (required) Directory with data splits.
                 Example: /pylon5/hm5fp1p/data/campaign5/splits/campaign3to5-1800x1200.v2-stamp-masked
  --campaign
      (required) Id of campaign. Example: "5"
  --set
      (required) Id of set. Example: "3"
  --run
      (required) Id of run. Example: "0"
  --results_root_dir
      (optional) The root dir of the directory with results. Default: "/pylon5/hm5fp1p/results/"
  --steps_per_epoch
      (optional) Number of steps per epoch. Default is 250.
  --version
      (optional) Version 2 adds SAVE_SNAPSHOT argument. Default: "2"
  --dry_run
      (optional) Enter 1 to NOT submit jobs. Default: "0"
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
    "results_root_dir"
    "steps_per_epoch"
    "version"
    "dry_run"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
results_root_dir="/pylon5/hm5fp1p/results"
steps_per_epoch=250
dry_run=0
version=2

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
        --results_root_dir)
            results_root_dir=$2
            shift 2
            ;;
        --steps_per_epoch)
            steps_per_epoch=$2
            shift 2
            ;;
        --version)
            version=$2
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
  echo "Argument 'set' is required."
  exit 1
fi
if [ -z "$run_id" ]; then
  echo "Argument 'run' is required."
  exit 1
fi

# The end of the parsing code.
################################################################################

script_dir=$(dirname "$0")
template_path="${script_dir}/template.sbatch"
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

results_dir="${results_root_dir}/campaign${campaign_id}/set${set_id}/run${run_id}"
echo "campaign_id: $campaign_id"
echo "set_id:      $set_id"
echo "run_id:      $run_id"
echo "results_dir: $results_dir"
echo "splits_dir:  $splits_dir"

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
    HYPER_N="${ADDR[0]}"
    SPLIT="${ADDR[1]}"
    BATCH_SIZE="${ADDR[2]}"
    LEARNING_RATE="${ADDR[3]}"
    EPOCHS="${ADDR[4]}"
    if [ ${version} -ge 1 ]; then
        echo "Template version is >1. Adding SAVE_SNAPHOT argument."
        SAVE_SNAPSHOTS="${ADDR[5]}"
    fi
    STEPS=${steps_per_epoch}

    NO_SNAPSHOTS_FLAG=""
    if [ ${version} -ge 1 ] && [ ${SAVE_SNAPSHOTS} == "0" ]; then
        NO_SNAPSHOTS_FLAG=" --no-snapshots"
    fi
    echo "NO_SNAPSHOTS_FLAG: ${NO_SNAPSHOTS_FLAG}"
    
    split_dir=$splits_dir/$SPLIT
    if [ ! -d "$split_dir" ]; then
        echo "Directory with a split does not exist at '$split_dir'"
        exit 1
    fi
    if [ ! -d "$split_dir/images/train2017" ]; then
        echo "Warning: Directory with TRAINING images does not exist at '$split_dir/images/train2017'"
        continue
    fi
    if [ ! -d "$split_dir/images/val2017" ]; then
        echo "Warning: Directory with VALIDATION images does not exist at '$split_dir/images/val2017'"
        continue
    fi
    if [ ! -f "$split_dir/annotations/instances_train2017.json" ]; then
        echo "Warning: File with TRAINING annotations does not exist at '$split_dir/annotations/instances_train2017.json'"
        continue
    fi
    if [ ! -f "$split_dir/annotations/instances_val2017.json" ]; then
        echo "Warning: File with VALIDATION annotations does not exist at '$split_dir/annotations/instances_val2017.json'"
        continue
    fi

    mkdir -p ${results_dir}/results/hyper${HYPER_N}/snapshots && \
    mkdir -p ${results_dir}/results/hyper${HYPER_N}/tensorboard && \
    mkdir -p ${results_dir}/input/hyper${HYPER_N}

    sed \
      -e "s|SPLIT_DIR|$split_dir|g" \
      -e "s|HYPER_N|${HYPER_N}|g" \
      -e "s|BATCH_SIZE|${BATCH_SIZE}|g" \
      -e "s|LEARNING_RATE|${LEARNING_RATE}|g" \
      -e "s|EPOCHS|${EPOCHS}|g" \
      -e "s|STEPS|${STEPS}|g" \
      -e "s|CAMPAIGN_ID|${campaign_id}|g" \
      -e "s|SET_ID|${set_id}|g" \
      -e "s|RUN_ID|${run_id}|g" \
      -e "s|NO_SNAPSHOTS_FLAG|${NO_SNAPSHOTS_FLAG}|g" \
      ${template_path} > "${results_dir}/input/hyper${HYPER_N}/hyper${HYPER_N}.sbatch"
    status=$?
    if [ ${status} -ne 0 ]; then
      echo "Failed to use the template from '${template_path}'"
      exit ${status}
    fi

    if [ ${dry_run} == "0" ]; then
      JID=$(sbatch -A hm5fp1p \
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
