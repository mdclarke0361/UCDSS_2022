#!/bin/bash

# NCBI Annotation File Conversion - GFF3 to GTF
# Version: May 07 2024
# Author: Mike Clarke, Faculty of Medical Microbiology and Infection, University of Alberta

# This program converts genome annotation files downloaded from the NCBI database. These files are in GFF3 format.
# A simple conversion will parse each line and create a new file in the GTF2 format: 
# (<seqname> <source> <feature> <start> <end> <score> <frame> gene_id "<Gene ID>"; transcript_id "<Transcript ID>";)
# for more information on the formatting, visit: https://github.com/NBISweden/GAAS/blob/master/annotation/knowledge/gxf.md
# The program will also convert any circular genomes into linear format by splitting genome features which overlap the
# origin into two features and reorganizing the feature parameters accordingly.

# Source initialization script
source 01_source/initialize_script.sh

# Stop flag to allow shutdown on interrupt
STOP=0
trap 'STOP=1; pkill -P $$; wait; exit' SIGINT SIGTERM

# Read in arguments
accession_list="${project_dir}/${1}"
annotation_file="${project_dir}/${2}"
sequence_file="${project_dir}/${3}"
output_dir="${project_dir}/${4}"

# Split large files to run concurrently with multiple processes
# Create temporary directories for splitting files
temp_dir=${output_dir}/_temp
mkdir -p $temp_dir

# Prepare files for splitting by removing anything before the first header line

sed -n '/^##sequence-region/,$p' "${annotation_file}" > "${annotation_file}.tmp" &&
	mv "${annotation_file}.tmp" "${annotation_file}"

sed -n '/^>/,$p' "${sequence_file}" > "${sequence_file}.tmp" &&
	mv "${sequence_file}.tmp" "${sequence_file}"

# Split the input files into temporary files, each with a single genome
csplit \
	-f "${temp_dir}/annotation_" \
	-b "%03d.tmp" \
	-s \
	-z \
	"${annotation_file}" \
	'/^##sequence-region/' '{*}'

csplit \
	-f "${temp_dir}/sequence_" \
	-b "%03d.tmp" \
	-s \
	-z \
	"${sequence_file}" \
	'/^>/' '{*}'

# Loop through temp dir
for temp_annotation_file in "${temp_dir}/annotation"*; do

	# If an interrupt was received, stop spawning new jobs
	if [[ "${STOP}" -eq 1 ]]; then

		break

	fi

	# Assign the corresponding sequence file
	temp_sequence_file="${temp_annotation_file/annotation/sequence}"

	{
	# First read through of file:
	# Determine the genome length (as linear), and the start and end
	# points of each feature.
	while read -r line && [[ -n "${line}" ]]; do

		if [[ "${line}" == "#"* ]]; then

			continue

		fi
        
		# Parse the line
		IFS=$'\t'
		read -ra feature_params <<< "$line"

		# Check the feature type for the line
		feature_type="${feature_params[2]}"

		# Get feature end-point
		feature_end="${feature_params[4]}"

		# Ignore the GenBank 'match' features
		if [[ "${feature_type}" == "match" ]]; then

			continue

		# Watch for region line
		elif [[ "${feature_type}" == "region" ]]; then

			# Set the length of the genome
			genome_length="${feature_end}"

			# Set the region end which is the maximum end-point
			# from the origin.
			region_end="${genome_length}"

			continue

		# Watch for feature that ovveruns genome length and maintain
		# a running maximum for overlap region and genome length
		elif [[ "${feature_end}" -gt "${region_end}" ]]; then

			# Set the new max for the region
			region_end="${feature_end}"

		fi

		accession="${feature_params[0]}"

	done < "${temp_annotation_file}"

	# Use the collected accession number to save a processed file
	# Only genomes with features other than 'region' will get an output
	processed_annotation_file="${temp_dir}/${accession}.gtf.tmp"
	processed_sequence_file="${temp_dir}/${accession}.fna.tmp"

	# If any overlapping features exist the file must be read through again
	# to catch any features that start within the overlap, but overrun the end of
	# the overlap.
	overlap=$(( region_end - genome_length ))

	if [[ "${overlap}" -gt 0 ]]; then
		
		echo "${accession} is circular!"

		# Read through the file
		while read -r line && [[ -n "${line}" ]]; do

			# Parse the line
			IFS=$'\t'
			read -ra feature_params <<< "$line"

			feature_type="${feature_params[2]}"
			feature_start="${feature_params[3]}"
			feature_end="${feature_params[4]}"
			
			# Ignore the GenBank 'match' features
			if [[ "${feature_type}" == "match" || "${feature_type}" == "region" ]]; then

				continue
			
			fi

			# Look for features that start in overlap and end
			# past the overlap
			if [[ "${feature_start}" -lt "${overlap}" && "${feature_end}" -gt "${overlap}" ]]; then
				
				# Adjust overlap region to include the entire feature
				overlap="${feature_end}"

				# Set the corrected region end
				region_end=$(( genome_length + feature_end ))

			fi

		done < "${temp_annotation_file}"

		# Make the neccessary changes to the sequence file
		# Retrieve sequence string from fasta file
		sequence_header=$(head -n1 "$temp_sequence_file")
		original_seq=$(grep -v '^>' "$temp_sequence_file" | tr -d '\n')

		# Get overlapping sequence
		sequence_overlap=${original_seq:0:${overlap}}

		# Replace the begining of the sequence with repeating N characters
		printf -v repeating_n '%*s' "$overlap" ''
		repeating_n=${repeating_n// /N}

		# Assemble the new sequence string
		new_sequence="${repeating_n}${original_seq:$overlap}${sequence_overlap}"

		# Write header + new sequence to a temp file
		printf '%s\n' "$sequence_header" >> "${processed_sequence_file}"
		printf '%s\n' "$new_sequence" | fold -w70 >> "${processed_sequence_file}"

	else

		# The genome is linear, so just copy the sequence file over
		cat "${temp_sequence_file}" >> "${processed_sequence_file}"

	fi

	# Second (or third) read through of file:
	# Read through the file to convert lines to GTF
	while read -r line && [[ -n "${line}" ]]; do

		# Look for header lines and pass straight to output file
		if [[ "${line}" == "#"* ]]; then

			printf "%s\n" "$line" >> "${processed_annotation_file}"

			continue

		fi

		# Parse the line
		IFS=$'\t'
		read -ra feature_params <<< "$line"

		feature_type="${feature_params[2]}"
		feature_start="${feature_params[3]}"
		feature_end="${feature_params[4]}"
		
		# Ignore the GenBank 'match' features
		if [[ "${feature_type}" == "match" ]]; then

			continue

		# If 'region' line
		elif [[ "${feature_type}" == "region" ]]; then
            
			# Set region end
			feature_end="${region_end}"
		
		# If genome is circular and the feature is within the overlapping region
		# then move it from the start to the overlap sequence.
		elif [[ "${feature_start}" -lt "${overlap}" ]]; then

			#
			feature_start=$(( feature_start + genome_length ))
			feature_end=$(( feature_end + genome_length ))

		fi

		# Assign all other feature params
		accession="${feature_params[0]}"
		source="${feature_params[1]}"
		score="${feature_params[5]}"
		strand="${feature_params[6]}"
		frame="${feature_params[7]}"

		# Split the attributes string into separate parameters
		attributes="${feature_params[8]}"

		# Get a gene_id, used for grouping features for counting by genes
		# Note: This can vary by source database and may need to be updated as necessary.
		gene_id=$(echo "${attributes}" | grep -oP 'Dbxref=[^:]*:\K[^,;]*(?=,|;|$)')

		# Fall back to another possible pattern if 'Dbxref' fails - this occurs with pseudogenes, etc.
		if [[ -z $gene_id ]]; then

			gene_id=$(echo "${attributes}" | grep -oP 'Parent=\K[^,;]*(?=,|;|$)')

		fi

		# Get a transcript_id (must be unique)
		transcript_id="${accession}:${feature_start}..${feature_end}"

		# Print the GTF-formatted feature string
		printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
			"${accession}" "${source}" "${feature_type}" "${feature_start}" "${feature_end}" "${score}" "${strand}" \
				"${frame}" "gene_id \"${gene_id}\"; transcript_id \"${transcript_id}\";" \
			>> "${processed_annotation_file}"

	done < "${temp_annotation_file}"

	echo "finished ${accession}"

	} &

	# Throttle to thread limit
	while [[ $(jobs -r -p | wc -l) -ge ${threads} ]]; do

		if [[ "${STOP}" -eq 1 ]]; then

			break 2

		fi

		sleep 0.1

	done

done

# Wait for the entire processing of temp files to finish before joining
# temporary files
wait

# Assign output files
output_annotation_file="${output_dir}/$(basename $annotation_file)"
output_annotation_file="${output_annotation_file%.*}_converted.gtf"
output_sequence_file="${output_dir}/$(basename $sequence_file)"
output_sequence_file="${output_sequence_file%.*}_converted.fna"

touch "${output_annotation_file}"
touch "${output_sequence_file}"

while read -r acc; do

	# Check if a processed file exists
	cat_annotation_file="${temp_dir}/${acc}.gtf.tmp"
	cat_sequence_file="${temp_dir}/${acc}.fna.tmp"

	if [[ -f "${cat_annotation_file}" ]]; then

		cat "${cat_annotation_file}" >> "${output_annotation_file}"
		printf "\n" >> "${output_annotation_file}"

		cat "${cat_sequence_file}" >> "${output_sequence_file}"
		printf "\n" >> "${output_sequence_file}"

	else
		
		echo "${acc} was not processed..."
	
	fi

done < "${accession_list}"

rm -r "${temp_dir}"