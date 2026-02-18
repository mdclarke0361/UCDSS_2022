#!/bin/bash

# Run alignment of remaining RNAseq reads against the viral database using STAR aligner.

# Source initialization script
source 01_source/initialize_script.sh

# Read in arguments
unaligned_read_file_dir=${project_dir}/${1}
index_dir=${project_dir}/${2}

# Create dirs for final output files
viral_aligned_dir=${processed_data_dir}/viral_aligned
temp_alignment_dir=${viral_aligned_dir}/_temp
mkdir -p $temp_alignment_dir

#
star_log_dir=${log_out}/viral_star_logs
mkdir -p $star_log_dir

#
for fwd_read in "${unaligned_read_file_dir}"/*R1.fastq; do

	rev_read=${fwd_read/R1/R2}

	sample_name=$(basename $fwd_read)
	sample_name=${sample_name/_unaligned_R1.fastq/}

	file_list="${fwd_read} ${rev_read}"

	# Run STAR alignment
	STAR \
		--runThreadN $threads \
		--genomeDir $index_dir \
		--readFilesIn $file_list \
		--outSAMtype BAM Unsorted \
		--outFileNamePrefix $temp_alignment_dir/ \
		--winAnchorMultimapNmax 200 \
		--outFilterMultimapNmax 100 \
		--outFilterMismatchNmax 5 \
		--alignIntronMax 1

	# Rename output files and organize into new directories

	mv ${temp_alignment_dir}/Aligned.out.bam ${viral_aligned_dir}/${sample_name}.bam
	mv ${temp_alignment_dir}/Log.out ${star_log_dir}/${sample_name}.Log.out
	mv ${temp_alignment_dir}/Log.final.out ${star_log_dir}/${sample_name}.Log.final.out

done

# Clean up all temporary files
rm -r $temp_alignment_dir
