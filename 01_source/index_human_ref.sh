#!/bin/bash

# Source initialization script
source 01_source/initialize_script.sh

# Read in arguments
ref_genome=${PROJECT_DIR}/${1}
ref_annotation=${PROJECT_DIR}/${2}

# Create output directory for indexed genome
index_dir="${REF_DATA_DIR}/human_ref_index"
mkdir -p $index_dir

# Run indexing command
STAR \
	--runMode genomeGenerate \
	--runThreadN $THREADS \
	--genomeDir $index_dir \
	--genomeFastaFiles "${ref_genome}" \
	--sjdbGTFfile "${ref_annotation}"

# Notify user of output location
echo "Indexing complete. Index saved to: ${YELLOW}${index_dir}${NC}"