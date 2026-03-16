#!/bin/bash

#

# Source initialization script
source 01_source/initialize_script.sh

# Read in arguments
aligned_reads_dir=${PROJECT_DIR}/${1}
viral_ref_annotation_file=${PROJECT_DIR}/${2}

# Set a name for output count report dir
count_report_file=${PROCESSED_DATA_DIR}/viral_tx_counts.txt
feature_counts_log_file="${LOG_DIR}/viral_tx_count_summary.log"

# Get file list of aligned read files to pass to feature counts
file_list=$(
	find $aligned_reads_dir \
	-type f \
	-name "*.bam" |
	sort
)

# Use 'CDS' instead of 'exon' for feature name.
# Count multimapping reads (filtering was done by STAR)
featureCounts \
	-a $viral_ref_annotation_file \
	-M \
	-t "CDS" \
	-T $THREADS \
	-p \
	--countReadPairs \
	--largestOverlap \
	-o $count_report_file \
	$file_list

# Move automatically created log file
mv "${count_report_file}.summary" $feature_counts_log_file

# Notify user of output location
echo -e "Transcript counting complete." \
	"Report file saved to: ${YELLOW}${count_report_file}${NC}" \
	"Log file saved to: ${YELLOW}${feature_counts_log_file}${NC}"

