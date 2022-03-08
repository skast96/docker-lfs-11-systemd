#!/bin/bash
#
# Script Name: run-stages.sh
#
# Author: Stephan Kast
# Date : 08.03.2022
#
# Description: The following script runs all build stages
#

# Iterates through all stages of $STAGES
# stages need to have a entry.sh script as entrypoint of this stage
run_stages() {
  for stage in stage*/; do

    echo "Starting $stage"
    cd $stage || exit 1

    echo "Running entry"
    bash ./entry.sh || exit 1

    touch SKIP
    echo "Finished $stage"
    cd ..
  done

}

run_stages
