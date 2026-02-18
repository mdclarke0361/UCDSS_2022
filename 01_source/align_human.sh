#!/bin/bash

# Run alignment of trimmed RNAseq reads against the human genome using STAR aligner.

# Source initialization script
source 01_source/initialize_script.sh

# Read in arguments
trimmed_read_file_dir=${project_dir}/${1}
index_dir=${project_dir}/${2}

#
temp_alignment_dir=${processed_data_dir}/alignment_temp
mkdir -p $temp_alignment_dir

# Create dirs for final output files
human_aligned_dir=${processed_data_dir}/human_aligned
unaligned_dir=${processed_data_dir}/unaligned
mkdir -p $human_aligned_dir
mkdir -p $unaligned_dir

# Create separate dir for log files
star_log_dir=${log_out}/human_star_logs
mkdir -p $star_log_dir

for sample_name in "$trimmed_read_file_dir"/*; do

	sample_basename=$(basename $sample_name)

	# Compile list of filenames for STAR input
	fwd_reads=$(
		find $sample_name \
		-type f \
		-name "*R1.fastq.gz" |
		sort |
		# paste together filenames using comma delimeter
		paste -sd ","
	)

	rev_reads=$(
		find $sample_name \
		-type f \
		-name "*R2.fastq.gz" |
		sort |
		paste -sd ","
	)

	input_files="${fwd_reads} ${rev_reads}"
	
	# Run STAR alignment and save unaligned files
	STAR \
		--runThreadN $threads \
		--genomeDir $index_dir \
		--readFilesIn $input_files \
		--readFilesCommand zcat \
		--outFilterMultimapNmax 20 \
		--outFileNamePrefix ${temp_alignment_dir}/${sample_basename}_ \
		--outSAMtype BAM Unsorted \
		--outReadsUnmapped Fastx

	# Assign names for files to be moved and renamed
	aligned_file=${temp_alignment_dir}/${sample_basename}_Aligned.out.bam
	unaligned_fwd_file=${temp_alignment_dir}/${sample_basename}_Unmapped.out.mate1
	unaligned_rev_file=${temp_alignment_dir}/${sample_basename}_Unmapped.out.mate2
	star_run_log=${temp_alignment_dir}/${sample_basename}_Log.out
	star_final_log=${temp_alignment_dir}/${sample_basename}_Log.final.out

	# Move alignment files
	mv $aligned_file ${human_aligned_dir}/${sample_basename}.bam
	mv $unaligned_fwd_file ${unaligned_dir}/${sample_basename}_unaligned_R1.fastq
	mv $unaligned_rev_file ${unaligned_dir}/${sample_basename}_unaligned_R2.fastq

	# Move log files
	mv $star_run_log ${star_log_dir}/${sample_basename}_run.log
	mv $star_final_log ${star_log_dir}/${sample_basename}_summary.log

done

# Clean up all temporary files
rm -r $temp_alignment_dir
