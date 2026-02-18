#!/bin/bash

# Source initialization script
source 01_source/initialize_script.sh

# Read in arguments
ref_genome=${project_dir}/${1}
ref_annotation=${project_dir}/${2}
index_dir=${project_dir}/${3}

#
mkdir -p $index_dir

#
STAR \
	--runMode genomeGenerate \
	--runThreadN $threads \
	--genomeDir $index_dir \
	--genomeFastaFiles "${ref_genome}" \
	--sjdbGTFfile "${ref_annotation}"
