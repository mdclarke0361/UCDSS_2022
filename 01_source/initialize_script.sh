#!/bin/bash

# Initialize project bash scripts.

# Get path for project directory based on the calling script
export SCRIPT_DIR=$(dirname "${0}/")
export PROJECT_DIR=$(dirname "${SCRIPT_DIR}/")

# Get the name of the calling script without path or suffix
script=$(basename $0)
export SCRIPT_NAME="${script%.*}"

# Get path for project directories.
export RAW_DATA_DIR="${PROJECT_DIR}/02_data/raw" # Input data, does not change
export PROCESSED_DATA_DIR="${PROJECT_DIR}/02_data/processed" # Output Data from program
export REF_DATA_DIR="${PROJECT_DIR}/02_data/reference" # Downloaded data for reference
export FIGURE_DIR="${PROJECT_DIR}/03_results/figures" # Output figures
export REPORT_DIR="${PROJECT_DIR}/03_results/reports" # Output reports (ex. QA/QC)
export TABLE_DIR="${PROJECT_DIR}/03_results/tables" # Output tables
export LOG_DIR="${PROJECT_DIR}/03_results/logs" # Output logs from program runs

# Ensure all project directories exist
subdirs=(

	# Data directories
	"$RAW_DATA_DIR" "$PROCESSED_DATA_DIR" "$REF_DATA_DIR"
	# Results directories
	"$FIGURE_DIR" "$REPORT_DIR" "$TABLE_DIR" "$LOG_DIR"

)

for dir in "${subdirs[@]}"; do

	mkdir -p $dir

done

# Create a default name for log file based on script name
export LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"

# Get the number of threads to use, assign 80% of them for the calling script.
core_total=$(nproc --all)
THREADS=$(echo "${core_total}*0.5" | bc -l)
export THREADS=${THREADS%.*}

# Set up of text colors for terminal output.
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export NC='\033[0m' # Reset to default

# Create a function to create timestamps 
TIMESTAMP () {

    local timestamp=$(date +"%D %H:%M:%S")
    echo "${timestamp} "

}

# Initialize new log file
echo "Program: ${SCRIPT_NAME}" "Started: $(TIMESTAMP)" > $LOG_FILE

