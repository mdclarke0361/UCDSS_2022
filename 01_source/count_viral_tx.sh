#!/bin/bash

#

# Source initialization script
source 01_source/initialize_script.sh

# Read in arguments
aligned_reads_dir=${project_dir}/${1}
viral_ref_annotation_file=${project_dir}/${2}

# Set a name for output count report dir
count_report_file=${report_out}/viral_tx_counts.txt

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
mv ${count_report_file}.summary ${log_out}/viral_tx_count_summary.log
