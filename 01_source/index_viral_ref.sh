#!/bin/bash

# Source initialization script
source 01_source/initialize_script.sh

# Read in arguments
ref_genome=${project_dir}/${1}
ref_annotation=${project_dir}/${2}

index_dir="${REF_DATA_DIR}/virome_ref_index"

mkdir -p $index_dir

# Run STAR to generate index.
# Reduce genomeSAindexNbases from default due to genome size.
# Change the default feature type to look for to 'CDS' as this is
# used more frequently to indicate exons in viral genomes.
STAR \
	--runMode genomeGenerate \
	--runThreadN $threads \
	--genomeSAindexNbases 12 \
	--sjdbGTFfeatureExon "CDS" \
	--genomeDir $index_dir \
	--genomeFastaFiles $ref_genome \
	--sjdbGTFfile $ref_annotation

# Notify user of output location
echo "Indexing complete. Index saved to: ${YELLOW}${index_dir}${NC}"
