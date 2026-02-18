#!/bin/bash

# Run QC on the unaligned fastq files

# Source initialization script
source 01_source/initialize_script.sh

# Read in arguments
raw_read_file_dir=${project_dir}/${1}

# Loop through the raw data directory to access sample directories.
for sample_name in "$raw_read_file_dir"/*; do

	# Create per-sample directories for reports
	qc_report_dir="$report_out"/raw_data_qc/"$(basename $sample_name)"
	mkdir -p $qc_report_dir

	# Get list of reads to be processed
	read_list=$(
		find $sample_name \
		-type f \
		-name "*.fastq.gz"
	)

	((i=i%threads)); ((i++==0)) && wait

	fastqc \
		-o $qc_report_dir \
    	--noextract \
    	$read_list &

	# Wait for fastqc files to be produced before starting multiqc
	wait

	# Run multiqc to get summary reports for each sample.
	multiqc_report_name="${qc_report_dir}/multiqc_report_$(basename $sample_name).html"

	multiqc \
		--filename $multiqc_report_name \
		--no-data-dir \
		--interactive \
		$qc_report_dir

done
