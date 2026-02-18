#!/bin/bash

#

# Source initialization script
source 01_source/initialize_script.sh

# Read in arguments
aligned_reads_dir=${project_dir}/${1}
human_ref_annotation_file=${project_dir}/${2}

# Set a name for output count report
count_report_file=${report_out}/human_tx_counts.txt

# Get file list of aligned read files to pass to feature counts
file_list=$(
	find $aligned_reads_dir \
	-type f \
	-name "*.bam" |
	sort
)

#
featureCounts \
	-a $human_ref_annotation_file \
	-p \
	--countReadPairs \
	-T $threads \
	-o $count_report_file \
	$file_list

# Move automatically created log file
mv ${human_count_report_file}.summary ${log_out}/human_tx_count_summary.log