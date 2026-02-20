#!/bin/bash

# Initialize project bash scripts.

# Get path for project directory based on the calling script.
script_dir=$(dirname $0)
export PROJECT_DIR=$(dirname $script_dir)

# Ensure all project directories exist, if not, create them.
subdirectories=(
	# Data directories
	"02_data/metadata" "02_data/processed" "02_data/raw" "02_data/reference"
	# Results directories
	"03_results/figures" "03_results/reports" "03_results/tables" "03_results/logs"
)

for dir in "${subdirectories[@]}"; do

	mkdir -p ${PROJECT_DIR}/${dir}

done

# Get path for project directories set them as capitilized to indicate source.
export METADATA_DIR="${PROJECT_DIR}/02_data/metadata"
export PROCESSED_DATA_DIR="${PROJECT_DIR}/02_data/processed"
export RAW_DATA_DIR="${PROJECT_DIR}/02_data/raw"
export REF_DATA_DIR="${PROJECT_DIR}/02_data/reference"
export FIGURE_DIR="${PROJECT_DIR}/03_results/figures"
export REPORT_DIR="${PROJECT_DIR}/03_results/reports"
export TABLE_DIR="${PROJECT_DIR}/03_results/tables"
export LOG_DIR="${PROJECT_DIR}/03_results/logs"

# Get the number of threads to use based on desired processor use.
core_total=$(nproc --all)
THREADS=$(echo "${core_total}*0.8" | bc -l)
export THREADS=${THREADS%.*}

# Set up of text colors for terminal output.
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export NC='\033[0m' # Reset to default