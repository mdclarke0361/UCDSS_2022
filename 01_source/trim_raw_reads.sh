#!/bin/bash

# Run fastp on the raw RNAseq files to trim adapters and output post-trim quality.

# Source initialization script
source 01_source/initialize_script.sh

# Stop flag to allow shutdown on interrupt
STOP=0
trap 'STOP=1; pkill -P $$; wait; exit' SIGINT SIGTERM

# Read in arguments
raw_read_file_dir="${project_dir}/${1}"

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

for sample_name in "${raw_read_file_dir}"/*; do


	# If an interrupt was received, stop spawning new jobs
	if [[ "${STOP}" -eq 1 ]]; then

		break

	fi

	{

	# Create per-sample directories for processed data and reports
	trimmed_reads_dir="${processed_data_dir}/trimmed_reads/$(basename ${sample_name})"
	mkdir -p "${trimmed_reads_dir}"

	trim_report_dir="${report_out}/trimming/$(basename ${sample_name})"
	mkdir -p "${trim_report_dir}"

	fwd_reads=$(
		find "${sample_name}" \
		-type f \
		-name "*R1.fastq.gz"
	)

	# loop through read list
	for read in $fwd_reads; do

		# Assume reverse read is named the same with R2 suffix
		fwd_read=$read
		rev_read=${read/R1/R2}

		fwd_read_out="${trimmed_reads_dir}/$(basename $fwd_read)"
		rev_read_out="${trimmed_reads_dir}/$(basename $rev_read)"

		report_name="$(basename ${read})"
		report_name="$trim_report_dir"/"${report_name/_R1/}"

		fastp \
			-i "$fwd_read" \
			-o "$fwd_read_out" \
			-I "$rev_read" \
			-O "$rev_read_out" \
			-j "${report_name}.json" \
			-h "${report_name}.html" \
			-V \
			--detect_adapter_for_pe \
			--trim_poly_x \
			--overrepresentation_analysis \
			--thread "${fastp_processes}"

	done
	
	# Assemble per-sample reports with multiqc
	multiqc_report_name="$trim_report_dir"/"multiqc_report_$(basename $sample_name).html"
	
	multiqc \
		--filename $multiqc_report_name \
		--no-data-dir \
		--interactive \
		$trim_report_dir

	printf "\n"

	} &

	# Throttle to thread limit
	while [[ $(jobs -r -p | wc -l) -ge "${parallel_runs}" ]]; do

		if [[ "${STOP}" -eq 1 ]]; then

			break 2

		fi

		sleep 0.1

	done

done
