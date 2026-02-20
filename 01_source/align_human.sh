#!/bin/bash

# Run alignment of trimmed RNAseq reads against the human genome using STAR aligner.

# Source initialization script
source 01_source/initialize_script.sh

# Read in arguments
trimmed_read_file_dir="${PROJECT_DIR}/${1}"
index_dir="${PROJECT_DIR}/${2}"

# Create temporary directory for temp output files
temp_alignment_dir="${PROCESSED_DATA_DIR}/alignment_temp"
mkdir -p $temp_alignment_dir

# Create dirs for final output files
human_aligned_dir=${PROCESSED_DATA_DIR}/human_aligned
unaligned_dir=${PROCESSED_DATA_DIR}/unaligned
mkdir -p $human_aligned_dir
mkdir -p $unaligned_dir

# Create separate dir for log files
star_log_dir=${LOG_DIR}/human_star_logs
mkdir -p $star_log_dir

for sample_dir in "${trimmed_read_file_dir}/"*; do

	#
	sample_dir=${1}
	sample_name=$(basename $sample_dir)

	# Compile list of filenames for STAR input
	fwd_reads=$(
		find $sample_dir \
		-type f \
		-name "*R1.fastq.gz" |
		sort |
		# paste together filenames using comma delimeter
		paste -sd ","
	)

	rev_reads=$(
		find $sample_dir \
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
		--outFileNamePrefix "${temp_alignment_dir}/${sample_name}_" \
		--outSAMtype BAM Unsorted \
		--outReadsUnmapped Fastx

	# Assign names for files to be moved and renamed
	aligned_file="${temp_alignment_dir}/${sample_name}_Aligned.out.bam"
	unaligned_fwd_file="${temp_alignment_dir}/${sample_name}_Unmapped.out.mate1"
	unaligned_rev_file="${temp_alignment_dir}/${sample_name}_Unmapped.out.mate2"
	star_run_log="${temp_alignment_dir}/${sample_name}_Log.out"
	star_final_log="${temp_alignment_dir}/${sample_name}_Log.final.out"

	# Move alignment files
	mv $aligned_file "${human_aligned_dir}/${sample_name}.bam"
	mv $unaligned_fwd_file "${unaligned_dir}/${sample_name}_unaligned_R1.fastq"
	mv $unaligned_rev_file "${unaligned_dir}/${sample_name}_unaligned_R2.fastq"

	# Move log files
	mv $star_run_log "${star_log_dir}/${sample_name}_run.log"
	mv $star_final_log "${star_log_dir}/${sample_name}_summary.log"

done

# Clean up all temporary files
rm -r $temp_alignment_dir

# Notify user of output location
echo "Alignment complete." \
	"Aligned files saved to: ${YELLOW}${human_aligned_dir}${NC}" \
	"Unaligned files saved to: ${YELLOW}${unaligned_dir}${NC}" \
	"Alignment reports saved to: ${YELLOW}${star_log_dir}${NC}"
