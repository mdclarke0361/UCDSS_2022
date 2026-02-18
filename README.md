# UCDSS 2022 - RNAseq Analysis of Human Virome in Stroke

# Set Up
## Clone Repo
Clone this repo to desired project directory.

## Recreate Conda Env
Below is an example command. Create conda environment from environment.yml in main project directory.
Use desired project name in place of env_name.
```bash
env_name="UCDSS"

conda env create \
	--name $env_name \
	--file environment.yml
```

## Raw Data QC
For this project, all raw read files have been organized into separate directories with their associated sample name. The following script will reference the name of each directory as the sample name and use this to group the reads by sample.
```bash
raw_read_file_dir="02_data/raw/read_files"

bash 01_source/qc_raw_reads.sh \
    $raw_read_file_dir
```

## Trim Reads
Use fastp program to trim adapters and output.
Forward/reverse reads are detected using the 'R1'/'R2' designation in each fastq file.
```bash
raw_read_file_dir="02_data/raw/read_files"

bash 01_source/trim_raw_reads.sh \
    $raw_read_file_dir
```

# Alignment to Human Genome
Reference genome can be downloaded from NCBI database. To create an indexed genome for STAR to use, download the fasta sequence and GTF annotation file from NCBI.

The reference genome used in this project is GRCh38.p14.
```bash
download_temp_dir="02_data/reference/ncbi_download"

mkdir -p $download_temp_dir

download_temp_file=${download_temp_dir}/ncbi_dataset.zip

datasets download genome accession GCF_000001405.40 \
    --include "genome,gtf,seq-report" \
    --filename ${download_temp_file} \
	--dehydrated

# Unzip the downloaded data
unzip $download_temp_file \
    -d $download_temp_dir

datasets rehydrate \
	--directory $download_temp_dir

# Organize Files
gtf_file=$(
    find $download_temp_dir \
	-type f \
	-name "*.gtf"
)

fasta_file=$(
    find $download_temp_dir \
    -type f \
    -name "*.fna"
)

assembly_report=$(
    find $download_temp_dir \
    -type f \
    -name "sequence_report.jsonl"
)

mv $gtf_file 02_data/reference/ref_human_genome.fna
mv $fasta_file 02_data/reference/ref_human_annotation.gtf
mv $assembly_report 02_data/reference/ref_human_annotation_report.jsonl

rm -r $download_temp_dir
```

Prepare the reference genome for STAR run by generating a genome index.
```bash
ref_genome="02_data/reference/ref_human_genome.fna"
ref_annotation="02_data/reference/ref_human_annotation.gtf"
index_dir="02_data/reference/human_ref_index"

bash 01_source/index_human_ref.sh \
    $ref_genome \
    $ref_annotation \
    $index_dir
```

Run STAR alignment, and keep all unaligned files for further screening against a database of viral genomes.
```bash
trimmed_read_file_dir="02_data/processed/trimmed_reads"
index_dir="02_data/reference/human_ref_index"

bash 01_source/align_human.sh \
    $trimmed_read_file_dir \
    $index_dir
```

## Count Human Transcripts
Use FeatureCounts (subRead) to count human transcript alignments. 
```bash
human_aligned_dir="02_data/processed/human_aligned"
human_ref_annotation_file="02_data/reference/ref_human_annotation.gtf"

bash 01_source/count_human_tx.sh \
	$human_aligned_dir \
	$human_ref_annotation_file
```

Clean the count data in R and prepare for further processing steps.
```bash
human_gene_counts_file="02_data/processed/human_gene_counts.tsv"
human_annotation_report="02_data/reference/ref_human_annotation_report.jsonl"

Rscript 01_source/clean_human_count_data.r \
    $human_gene_counts_file \
    $human_annotation_report
```

# Generate Viral Genome Reference Files
For accurate alignement with a global alignment platform such as STAR aligner, a GTF annotation file should be provided. In a viral database, consisting of multiple viral genomes all concatenated into one sequence file, the annotation file will parse out features from each genome.

Although NCBI hosts the most comprehensive collection of viral genome sequences, the majority of these (with the exception of many segments from influenza isolates) are not part of a complete, and annotated 'NCBI Assembly', therefore it is not currently possible to directly download GTF annotation files for a large collection of viruses.

For this project, viral genomes are collected from the NCBI 'Nucleotide' database, as it is possible to collect both sequence files and GFF3 annotation files from the NCBI server. The annotation files will then be converted to GTF format in the following scripting processes.

## Download Sequence and Annotation Files
Note: The current command-line tool from NCBI which allows downloading of datasets does not support downloading of annotation files for viral genomes in the NCBI nucleotide database. The `datasets download genome` tool currently only accepts genome assemblies, for which there are only a handful of human viruses (mostly influenza segments). The dedicated virus tool, `datasets download virus genome` does not offer annotation files as an option for download. This may change at some point, however a workaround is outlined below: 

NCBI Virus - Find list of 'complete' nucleotides for viruses with a human host.

### All Human Viruses
Selection parameters on NCBI Virus:
Host = Human
Complete Nucleotides
Sequence Length > 1800

Retrieve the accession list from the website, then split the list into chunks.
```bash
accession_list_file="02_data/reference/all_virus_accession_list.acc"
temp_dir="02_data/reference/_temp"
mkdir -p "${temp_dir}"

split \
    -n 1000 \
	-d \
	--additional-suffix ".acc" \
    "${accession_list_file}" \
    "${temp_dir}/accession_list_"
```

Use the accession lists to download sequence and annotation files from NCBI. For genomes collected from the GenBank database, only GFF3 format annotation files will be available.
```bash
export NCBI_API_KEY="04983cea61c9d629bd3d5e241fca98f69109"
accession_list_dir="02_data/reference/_temp"
sequence_files_dir="02_data/reference/_temp_sequences"
annotation_files_dir="02_data/reference/_temp_annotations"

mkdir -p $sequence_files_dir
mkdir -p $annotation_files_dir

for accession_list_file in "$accession_list_dir"/*; do

    echo "Starting $(basename $accession_list_file)..."

    temp_sequence_file=$(basename $accession_list_file)
    temp_sequence_file="${temp_sequence_file%.*}.fna"

    temp_annotation_file=$(basename $accession_list_file)
    temp_annotation_file="${temp_annotation_file%.*}.gff3"

    epost -db nuccore -input "${accession_list_file}" \
        | efetch -format fasta \
        > ${sequence_files_dir}/${temp_sequence_file}

    epost -db nuccore -input "${accession_list_file}" \
        | efetch -format gff3 \
        > ${annotation_files_dir}/${temp_annotation_file}

    echo "Finished $(basename $accession_list_file)..."

done
```

### Human Herpesviruses
Selection parameters on NCBI Virus:
Host = Human
Complete Nucleotides
Taxon = Orthoherpesviridae

Retrieve the accession list from the website, then split the list into chunks.
```bash
accession_list_file="02_data/reference/herpesviruses_accession_list.acc"
temp_dir="02_data/reference/_temp"
mkdir -p "${temp_dir}"

split \
    -n 20 \
	-d \
	--additional-suffix ".tmp" \
    "${accession_list_file}" \
    "${temp_dir}/accession_list_"
```

Use the accession list to download sequence and annotation files from NCBI. For genomes collected from the GenBank database, only GFF3 format annotation files will be available.
```bash
accession_list="02_data/testing/herpesviruses_accession_list.acc"
export NCBI_API_KEY="04983cea61c9d629bd3d5e241fca98f69109"

epost -db nuccore -input "${accession_list}" \
    | efetch -format fasta \
    > "02_data/testing/herpesviruses_sequences.fna"

epost -db nuccore -input "${accession_list}" \
    | efetch -format gff3 \
    > "02_data/testing/herpesviruses_annotation.gff3"
```

## Convert GFF3 files
Run annotation conversion script to convert the GFF3 format to GTF2.2 (see http://mblab.wustl.edu/GTF22.html).
In addition, handle the annotation of circular genomes which have features that overrun the length of the linearly-represented geneome sequence.
```bash
accession_list="02_data/reference/herpesviruses_accession_list.acc"
annotation_file="02_data/reference/herpesviruses_annotation.gff3"
sequence_file="02_data/reference/herpesviruses_sequences.fna"
output_dir="02_data/reference"

bash 01_source/convert_viral_annotation.sh \
    $accession_list \
    $annotation_file \
    $sequence_file \
    $output_dir
```

A good check of the file is to `grep` all lines with 'CDS' and look at the attributes to see that the transcript IDs are unique and that the gene_ids make sense.

Note: Some of the records downloaded from NCBI will have a single 'region' line in their GFF3 file. These will result in an error thrown by the 'cat' command, because the script will not process any annotation file which does not contain feature lines. In this case, the errors may be ignored and the result will just omit these genomes which have not been properly annotated.

## Indexing Viral Genomes
Index the reference viral genomes for use with STAR alignment
```bash
ref_genome="02_data/reference/herpesviruses_sequences_converted.fna"
ref_annotation="02_data/reference/herpesviruses_annotation_converted.gtf"
index_dir="02_data/reference/herpesvirus_ref_index"

bash 01_source/index_viral_ref.sh \
    "${ref_genome}" \
    "${ref_annotation}" \
    "${index_dir}"
```

# Alignment to Viral Genomes

```bash
unaligned_read_file_dir="02_data/processed/unaligned"
index_dir="02_data/reference/herpesvirus_ref_index"

bash 01_source/align_viral.sh \
    $unaligned_read_file_dir \
    $index_dir
```

## Counting Viral Transcripts

```bash
aligned_reads_dir="02_data/processed/viral_aligned"
viral_ref_annotation_file="02_data/reference/herpesviruses_annotation_converted.gtf"

bash 01_source/count_viral_tx.sh \
	$aligned_reads_dir \
	$viral_ref_annotation_file
```

## Clean Viral Count Report
Clean the count data in R and prepare for further processing steps.

In the counts file:
- Chr is the <seqname> as defined in the GTF2.2 format.

```bash
viral_counts_file="03_results/reports/viral_tx_counts.txt"

Rscript 01_source/clean_viral_count_data.r \
    $viral_counts_file
```
