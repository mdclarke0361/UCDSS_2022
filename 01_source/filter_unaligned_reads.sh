#!/bin/bash

# Run fastp program for complexity filtering of reads.

# Source initialization script
source 01_source/initialize_script.sh

# Stop flag to allow shutdown on interrupt
STOP=0
trap 'STOP=1; pkill -P $$; wait; exit' SIGINT SIGTERM

# Read in arguments
unaligned_read_file_dir="${project_dir}/${1}"

# Create directory for filtered files
filtered_reads_dir="${processed_data_dir}/filtered_reads"
mkdir -p "${filtered_reads_dir}"

report_dir="${report_out}/filtering"
mkdir -p "${report_dir}"

# fastp is limited to 16 threads. Optimize the speed of this script by
# running each fastp command at the highest factor of the maximum thread.
i=16
N=$(( threads % i ))

while [[ $N -gt 0 ]]; do

	((i--))
	N=$(( threads % i ))

done

fastp_processes="${i}"
parallel_runs=$(( threads / fastp_processes ))

# Get file list of fwd reads
fwd_read_list=$(
	find $unaligned_read_file_dir \
	-type f \
	-name "*R1.fastq"
)

# Loop through the fwd read list 
for fwd_read in ${fwd_read_list}; do

	# If an interrupt was received, stop spawning new jobs
	if [[ "${STOP}" -eq 1 ]]; then

		break

	fi

	{

	# From the fwd read file, get the sample_name and rev read
	sample_name=$(basename "${fwd_read}")
	sample_name="${sample_name/_unaligned_R1.fastq/}"

	rev_read="${fwd_read/R1/R2}"

	fwd_read_out="${filtered_reads_dir}/${sample_name}_R1.fastq"
	rev_read_out="${filtered_reads_dir}/${sample_name}_R2.fastq"


	fastp \
		-i "${fwd_read}" \
		-o "${fwd_read_out}" \
		-I "${rev_read}" \
		-O "${rev_read_out}" \
		-V \
		-j "${report_dir}/${sample_name}.json" \
		-h "${report_dir}/${sample_name}.html" \
		--dont_overwrite \
		--overrepresentation_analysis \
		--low_complexity_filter \
		--thread "${fastp_processes}"

	} &

	# Throttle to thread limit
	while [[ $(jobs -r -p | wc -l) -ge "${parallel_runs}" ]]; do

		if [[ "${STOP}" -eq 1 ]]; then

			break 2

		fi

		sleep 0.1
	
	done

done


multiqc \
	--outdir "${report_dir}" \
	--no-data-dir \
	--interactive \
	$report_dir

printf "\n"
