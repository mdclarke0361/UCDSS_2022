#!/bin/bash

# Run fastp on the raw RNAseq files to trim adapters and output post-trim quality.

# Source initialization script
source 01_source/initialize_script.sh

# Prevent persistent process spawning by trapping keyboard interrupt
trap "kill 0" SIGINT

# Read in arguments
raw_read_file_dir="${PROJECT_DIR}/${1}"

# Create output directories
trimmed_reads_dir="${PROCESSED_DATA_DIR}/trimmed_reads"
trim_report_dir="${REPORT_DIR}/trimming"

# fastp is limited to 16 threads. Optimize the speed of this script by
# running each fastp command at the highest factor of the maximum thread.
i=16
N=$(( THREADS % i ))

while [[ $N -gt 0 ]]; do

	((i--))
	N=$(( THREADS % i ))

done

fastp_processes="${i}"
parallel_runs=$(( THREADS / fastp_processes ))

# Create function to run fastp program
trim_reads () {

	#
	sample_dir=${1}
	sample_name=$(basename $sample_dir)

	# Create per-sample directories for processed data and reports
	trimmed_reads_sub="${trimmed_reads_dir}/${sample_name}"
	mkdir -p "${trimmed_reads_sub}"

	trim_report_sub="${trim_report_dir}/${sample_name}"
	mkdir -p "${trim_report_sub}"

	fwd_reads=$(
		find "${sample_dir}" \
		-type f \
		-name "*R1.fastq.gz"
	)

	# loop through read list
	for read in $fwd_reads; do

		# Assume reverse read is named the same with R2 suffix
		fwd_read=$read
		rev_read=${read/R1/R2}

		# Set names for output files
		fwd_read_out="${trimmed_reads_sub}/$(basename $fwd_read)"
		rev_read_out="${trimmed_reads_sub}/$(basename $rev_read)"

		# Set report name
		report_name="$(basename ${read})"
		report_name="$trim_report_sub"/"${report_name/_R1/}"

		fastp \
			-i $fwd_read \
			-o $fwd_read_out \
			-I $rev_read \
			-O $rev_read_out \
			-j "${report_name}.json" \
			-h "${report_name}.html" \
			-V \
			--detect_adapter_for_pe \
			--low_complexity_filter \
			--trim_poly_x \
			--overrepresentation_analysis \
			--thread $fastp_processes

	done
	
	# Assemble per-sample reports with multiqc
	multiqc_report_name="${trim_report_dir}/multiqc_report_${sample_name}.html"
	
	multiqc \
		--filename $multiqc_report_name \
		--no-data-dir \
		--interactive \
		$trim_report_dir

}

# Loop the function with multiple parallel runs
for subdir in "${raw_read_file_dir}/"*; do

	trim_reads $subdir &

	# Throttle to thread limit
	while [[ $(jobs -r -p | wc -l) -ge "${parallel_runs}" ]]; do

		sleep 0.1

	done

done

# Notify user of output location
echo "Trimming complete. Trimmed reads saved to: ${YELLOW}${trimmed_reads_dir}${NC}" \
	"Trimming reports saved to: ${YELLOW}${trim_report_dir}${NC}"