#!/bin/bash

# Run featureCounts to count human gene transcripts in alignment files.

# Source initialization script
source "01_source/initialize_script.sh"

# Read in arguments
aligned_reads_dir="${PROJECT_DIR}/${1}"
human_ref_annotation_file="${PROJECT_DIR}/${2}"

# Set a name for output count report
count_report_file="${PROCESSED_DATA_DIR}/human_tx_counts.txt"
feature_counts_log_file="${LOG_DIR}/human_tx_count_summary.log"

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
mv "${count_report_file}.summary" $feature_counts_log_file

# Notify user of output location
echo "Transcript counting complete." \
	"Report file saved to: ${YELLOW}${count_report_file}${NC}" \
	"Log file saved to: ${YELLOW}${feature_counts_log_file}${NC}"
