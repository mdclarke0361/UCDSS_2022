#!/bin/bash

# Run QC on the unaligned fastq files
#

# Source initialization script
source 01_source/initialize_script.sh

# Prevent persistent process spawning by trapping keyboard interrupt
trap "kill 0" SIGINT

# Read in arguments
raw_read_file_dir="${PROJECT_DIR}/${1}"

# Create output directories
qc_report_dir="${REPORT_DIR}/raw_data_qc"

# Define a function to generate reports
generate_qc_reports () {

	#
	sample_dir=${1}
	sample_name=$(basename $sample_dir)

	# Create per-sample directories for reports
	qc_report_sub="${qc_report_dir}/${sample_name}"
	mkdir -p $qc_report_sub

	# Get list of reads to be processed
	read_list=$(
		find $sample_dir \
		-type f \
		-name "*.fastq.gz"
	)

	fastqc \
		-o $qc_report_sub \
    	--noextract \
    	$read_list

	# Run multiqc to get summary reports for each sample.
	multiqc_report_name="${qc_report_dir}/multiqc_report_${sample_name}.html"

	multiqc \
		--filename $multiqc_report_name \
		--no-data-dir \
		--interactive \
		$qc_report_sub

}

# Loop through the raw data directory to access sample directories.
for subdir in "${raw_read_file_dir}/"*; do

	generate_qc_reports $subdir &

	# Throttle to thread limit
	while [[ $(jobs -r -p | wc -l) -ge $THREADS ]]; do

		sleep 0.1

	done

done

# Notify user of output location
echo "Quality report created. QC reports saved to: ${YELLOW}${qc_report_dir}${NC}"
