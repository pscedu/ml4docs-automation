#!/bin/bash

# Not using "set -e" because grep will return an error code if it found no matches.

# Parse command line arguments.
PROGNAME=${0##*/}
usage()
{
  cat << EO
Start stamp-detection model training.

Usage:
  $PROGNAME

Example:
  $PROGNAME

Options:
  --grep_str
      (optional). Default: ''
EO
}

ARGUMENT_LIST=(
    "grep_str"
)

opts=$(getopt \
    --longoptions "help,""$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
    --name "$(basename "$0")" \
    --options "h" \
    -- "$@"
)

# Defaults.
grep_str="\'\'"

eval set --$opts

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --grep_str)
            grep_str=$2
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

echo "---------   Arguments   -----------"
echo "grep_str:               ${grep_str}"
echo "-----------------------------------"

# The end of the parsing code.
################################################################################

# Import all constants.
dir_of_this_file=$(dirname $(readlink -f $0))
source ${dir_of_this_file}/../constants.sh

# Check all the jobs in our account 
# (except for the jupiter notebook (ondemand), which is probably actually running this).
num_jobs="$(squeue -A ${ACCOUNT} | grep -v 'ondemand' | grep -v 'JOBID' | grep -c ${grep_str})"

if [ $num_jobs -eq 0 ]; then
  echo "All jobs finished. Safe to go to the next step."
else 
  echo "Still have ${num_jobs} running jobs."
fi
