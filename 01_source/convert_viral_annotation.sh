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
source "01_source/initialize_script.sh"

# Prevent persistent process spawning by trapping keyboard interrupt
trap "kill 0" SIGINT

# Read in arguments
annotation_files_dir="${PROJECT_DIR}/${1}"
sequence_files_dir="${PROJECT_DIR}/${2}"

# Create temporary directory for files being processed
temp_dir="${REF_DATA_DIR}/virome_ref/_temp"
mkdir -p $temp_dir

# Create files for final output
converted_annotation_file="${REF_DATA_DIR}/virome_ref/converted_virome_annotation.gtf"
converted_sequence_file="${REF_DATA_DIR}/virome_ref/converted_virome_sequence.fna"
touch $converted_annotation_file
touch $converted_sequence_file

# Create functions

split_file () {

	# Split large files to run concurrently with multiple processes
	
	# Read in arguments
	local file_to_split=$1
	
	# Set the pattern for splitting based on file type
	if [[ $file_to_split == *".gff3" ]]; then

		local suffix=".gff3"
		local pattern="##sequence-region"
		local acc_col=2

	else

		local suffix=".fna"
		local pattern=">"
		local acc_col=1

	fi

	# Remove lines above the first genome header and pipe
	# to splitting function
	sed -n "/^${pattern}/,\$p" $file_to_split |
		csplit \
			-f "${temp_split_dir}/"\
			-b "%03d${suffix}" \
			-s \
			-z \
			- \
			"/^${pattern}/" '{*}'

	# Rename the split files with the accession number of the genome
	for split_file in "${temp_split_dir}/"*"${suffix}"; do
		
		local accession
		accession=$(
			grep -m 1 "${pattern}" $split_file |
				awk "{print \$${acc_col}}" |
				sed 's/>//'
			)

		acc_filename="${temp_split_dir}/${accession}${suffix}"

		mv $split_file $acc_filename

	done

}

get_genome_params () {

	# Determine the genome length (as linear) and start/end of each feature.
	while read -r line && [[ -n $line ]]; do

		# Skip header lines
		if [[ $line == "#"* ]]; then

			continue

		fi
        
		# Parse the line by tab delimiter
		IFS=$'\t'
		read -ra feature_params <<< $line

		# Check the feature type for the line
		feature_type=${feature_params[2]}

		# Get feature end-point
		feature_end=${feature_params[4]}

		# Ignore the GenBank 'match' features
		if [[ $feature_type == "match" ]]; then

			continue

		# Watch for region line
		elif [[ $feature_type == "region" ]]; then

			# Set the length of the genome
			genome_length=$feature_end

			# Set the region end which is the maximum end-point
			# from the origin.
			region_end=$genome_length

			continue

		# Watch for feature that ovveruns genome length and maintain
		# a running maximum for overlap region and genome length
		elif [[ $feature_end -gt $region_end ]]; then

			# Set the new max for the region
			region_end=$feature_end

		fi

		accession=${feature_params[0]}

	done < $split_annotation_file

}

update_genome_params () {

	# Read through the file
	while read -r line && [[ -n $line ]]; do

		# Parse the line
		IFS=$'\t'
		read -ra feature_params <<< $line

		feature_type=${feature_params[2]}
		feature_start=${feature_params[3]}
		feature_end=${feature_params[4]}
		
		# Ignore the GenBank 'match' features
		if [[ $feature_type == "match" || $feature_type == "region" ]]; then

			continue
		
		fi

		# Look for features that start in overlap and end past the overlap
		if [[ $feature_start -lt $overlap && $feature_end -gt $overlap ]]; then
			
			# Adjust overlap region to include the entire feature
			overlap=$feature_end

			# Set the corrected region end
			region_end=$(( genome_length + feature_end ))

		fi

	done < $split_annotation_file

}

edit_sequence_file () {

	# Retrieve sequence string from fasta file
	sequence_header=$(head -n1 $split_sequence_file)
	original_seq=$(grep -v '^>' $split_sequence_file | tr -d '\n')

	# Get overlapping sequence
	sequence_overlap=${original_seq:0:${overlap}}

	# Replace the begining of the sequence with repeating N characters
	printf -v repeating_n '%*s' $overlap ''
	repeating_n=${repeating_n// /N}

	# Assemble the new sequence string
	new_sequence="${repeating_n}${original_seq:$overlap}${sequence_overlap}"

	# Write header + new sequence to a temp file
	printf '%s\n' $sequence_header >> $processed_sequence_file
	printf '%s\n' $new_sequence | fold -w70 >> $processed_sequence_file

}

check_circularity () {

	#

	#
	overlap=$(( region_end - genome_length ))

	if [[ $overlap -gt 0 ]]; then
		
		echo -e "${accession} is circular!" \
		>> $LOG_FILE

		# Get the updated lengths for the genome
		update_genome_params

		# Make the neccessary changes to the sequence file
		edit_sequence_file

	else

		# The genome is linear, so just copy the sequence file over
		cat $split_sequence_file >> $processed_sequence_file

	fi

}

convert_to_gtf () {

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

			# Move the feature to trailing end of the sequence
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
			"$accession" "$source" "$feature_type" "$feature_start" "$feature_end" "$score" "$strand" \
			"$frame" "gene_id \"${gene_id}\"; transcript_id \"${transcript_id}\";" \
			>> $processed_annotation_file

	done < $split_annotation_file

}

process_gff3 () {
	
	# Read through a GFF3 file and convert it to GTF2.2
	# Create a linear sequence and reference for circular genomes

	# First read through of annotation to get accession and genome length
	get_genome_params

	# If the genome is annotated then an accession will be assigned
	if [[ -n $accession ]]; then

		# Assign filenames for the converted files, using accession number
		processed_annotation_file="${temp_processed_dir}/${accession}.gff3"
		processed_sequence_file="${temp_processed_dir}/${accession}.fna"
		touch $processed_annotation_file
		touch $processed_sequence_file

		# If any overlapping features exist the file must be read through again
		# to catch any features that start within the overlap, but overrun the end of
		# the overlap.
		check_circularity

		# Second (or third) read through of file:
		# Read through the file to convert lines to GTF
		convert_to_gtf

		echo -e "$(TIMESTAMP)Processed ${accession}" >> $LOG_FILE

	else

		echo -e "$(TIMESTAMP)${split_annotation_file} does not have features." >> $LOG_FILE

		return

	fi

}

cat_processed_files () {

	#
	
	#
	for annotation_to_cat in "${temp_processed_dir}/"*".gff3"; do

		#
		sequence_to_cat=${annotation_to_cat/".gff3"/".fna"}

		# Cat converted files and add to final output
		cat $annotation_to_cat >> $converted_annotation_file
		printf "\n" >> $converted_annotation_file

		cat $sequence_to_cat >> $converted_sequence_file
		printf "\n" >> $converted_sequence_file

	done

}

# Main Program
main () {

	for annotation_file in "${annotation_files_dir}/"*; do

		# Get the index to use to match annotation and sequence files
		file_index=$(basename $annotation_file)
		file_index=${file_index%.*}

		echo -e "$(TIMESTAMP)Processing accessions from file number: ${YELLOW}${file_index}${NC}"

		# Create dir for split files
		temp_split_dir="${temp_dir}/split/${file_index}"
		mkdir -p $temp_split_dir

		# Create temp dir for processed files
		temp_processed_dir="${temp_dir}/converted/${file_index}"
		mkdir -p $temp_processed_dir

		# Get the filename for the sequence file to process
		sequence_file="${sequence_files_dir}/${file_index}.fna"

		# Split the annotation and sequence files and save into split dir
		split_file $annotation_file
		split_file $sequence_file
		
		# 
		for split_annotation_file in "${temp_split_dir}/"*.gff3; do

			#
			split_sequence_file=${split_annotation_file/".gff3"/".fna"}

			# Check that a matching sequence file exists
			if [ ! -f $split_sequence_file ]; then

				echo "$split_sequence_file does not exist!" >> $LOG_FILE

				continue

			fi

			#
			process_gff3 &

			# Throttle to thread limit
			while [[ $(jobs -r -p | wc -l) -ge $THREADS ]]; do

				sleep 0.1

			done

		done

		# Wait for the entire temp file to be processed
		wait

		echo -e "${GREEN}${annotation_file}${NC} processed. Writing temporary files to main output file..."

		cat_processed_files

		# Wait for all the files to write to final output
		wait

		# Clean up temporary files
		rm -r $temp_split_dir
		rm -r $temp_processed_dir

	done

	# Wait for all processes to finish
	wait

	# Delete temporary directory
	rm -rf $temp_dir

	echo -e "$(TIMESTAMP)Virome reference files converted." \
		"\nSequence file saved as: ${YELLOW}${converted_sequence_file}${NC}" \
		"\nAnnotation file saved as: ${YELLOW}${converted_annotation_file}${NC}"

}

main