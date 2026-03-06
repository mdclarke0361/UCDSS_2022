#!/bin/bash

#

# Source initialization script
source 01_source/initialize_script.sh

# Read in arguments
aligned_reads_dir=${PROJECT_DIR}/${1}
viral_ref_annotation_file=${PROJECT_DIR}/${2}

# Set a name for output count report dir
viral_tx_counts_file=${PROCESSED_DATA_DIR}/viral_tx_counts.txt

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
	-T $threads \
	-p \
	--countReadPairs \
	--largestOverlap \
	-o $count_report_file \
	$file_list

# Move automatically created log file
mv ${viral_tx_counts_file}.summary ${LOG_DIR}/viral_tx_count_summary.log
