# UCDSS 2022 - RNAseq Analysis of Human Virome in Stroke
This repo outlines the bioinformatics workflow used to characterize the human blood virome in patients with ischemic stroke using RNAseq data and a novel approach to alignment of viral transcripts using STAR aligner and an expansive database of reference viral genomes.

An overview of the process is as follows:
Input (from raw data directory):
- Total RNAseq data (fastq) from patient samples
- Sample metadata in .csv file

Process:
- QA with fastQC
- Adapter trimming, QC and complexity filtering with fastp
- Alignment to reference human genome
- Counting of human transcripts with featureCounts
- Compiling a reference viral genome database
- Alignment of non-human reads to viral genome database
- Counting of viral transcripts with featureCounts

Output:
- Human transcript counts as .txt file and R data object
- Viral transctipt counts as .txt file and R data object

# Set Up Project
The below code blocks run scripts that are stored in the 01_source folder. They are intended to be run as stand-alone units from the main repo directory. In this way, you may track your data input from each block, making changes as required and running each part of the analysis individually.

The file structure for the project is set within the scripts, the location of the output data is printed to stdout at the end of each script.

## Clone Repo
Clone this repo to desired project directory.

## Recreate Conda Env
Create conda environment from environment.yml in main project directory.

# 1 - Prepare Raw Data
## 1.1 - Raw Reads QC
For this project, all raw read files have been organized into separate directories with their associated sample name. The following script will reference the name of each directory as the sample name and use this to group the reads by sample.

Note: If your data does not have a separate directory for each sample name, then you may want to modify this step as required.
```bash
# Input data filenames
raw_read_file_dir="02_data/raw/read_files"

# Run script
bash "01_source/raw_reads_qc.sh" \
    $raw_read_file_dir
```

## 1.2 - Trim Raw Reads
Use fastp program to trim adapters.
Forward/reverse reads are detected using the 'R1'/'R2' designation in each fastq file and must otherwise share an identical filename.

Use a low complexity filter to eliminate sequencing artifacts and non-specific sequences often mistaken for viral genomes.
```bash
# Input data filenames
raw_read_file_dir="02_data/raw/read_files"

# Run script
bash "01_source/trim_raw_reads.sh" \
    $raw_read_file_dir
```

# 2 - Alignment to Human Genome
## 2.1 - Download Reference Genome
It is recommended to get an NCBI API key from the NCBI website in order to download reference genomes quicker. Once this is done, save the key as a text file named: "02_data/reference/NCBI_API_KEY"

Reference genome can be downloaded from NCBI database. To create an indexed genome for STAR to use, download the fasta sequence and GTF annotation file from NCBI.

The reference genome used in this project is GRCh38.p14

From the NCBI site, this corresponds to the assembly number GCF_000001405.40. You may need to change the assembly number in the below code if a different reference is required.
```bash
# Get API key from saved text file and export to global environment
ncbi_api_key_file="02_data/reference/NCBI_API_KEY"
export NCBI_API_KEY=$( < $ncbi_api_key_file)

# Set assembly number for reference genome version
assembly="GCF_000001405.40"

bash "01_source/get_human_ref.sh" \
    $assembly
```

## 2.2 - Index Human Reference Genome
Prepare the reference genome for STAR run by generating a genome index.
```bash
# Assign input filenames
ref_genome="02_data/reference/human_ref/ref_human_sequence.fna"
ref_annotation="02_data/reference/human_ref/ref_human_annotation.gtf"

# Run script
bash "01_source/index_human_ref.sh" \
    $ref_genome \
    $ref_annotation
```

## 2.3 - Run Human Alignment
Run STAR alignment, and keep all unaligned files for further screening against the database of viral genomes.
```bash
# Assign input filenames
trimmed_read_file_dir="02_data/processed/trimmed_reads"
index_dir="02_data/reference/human_ref/human_ref_index"

# Run script
bash "01_source/align_human.sh" \
    $trimmed_read_file_dir \
    $index_dir
```

## 2.4 - Count Human Transcripts
Use FeatureCounts (subRead) to count human transcript alignments.
Standard program settings are applied.
```bash
human_aligned_dir="02_data/processed/human_aligned"
human_ref_annotation_file="02_data/reference/human_ref/ref_human_annotation.gtf"

bash "01_source/count_human_tx.sh" \
	$human_aligned_dir \
	$human_ref_annotation_file
```

## 2.5 - Clean Human Count Data
Clean the count data in R and prepare for further processing steps.
Reference the annotation report that was downloaded from NCBI to assign parameters to transcripts.
```bash
human_tx_counts_file="02_data/processed/human_tx_counts.txt"
human_annotation_report_file="02_data/reference/human_ref/ref_human_annotation_report.jsonl"

Rscript "01_source/clean_human_count_data.r" \
    $human_tx_counts_file \
    $human_annotation_report_file
```

# 3 - Generate Viral Genome Reference Files
For accurate alignement with a global alignment platform such as STAR aligner, a GTF annotation file should be provided. In a viral database, consisting of multiple viral genomes all concatenated into one sequence file, the annotation file will parse out features from each genome.

Although NCBI hosts the most comprehensive collection of viral genome sequences, the majority of these (with the exception of many segments from influenza isolates) are not part of a complete, and annotated 'NCBI Assembly', therefore it is not currently possible to directly download GTF annotation files for a large collection of viruses.

For this project, viral genomes are collected from the NCBI 'Nucleotide' database, as it is possible to collect both sequence files and GFF3 annotation files from the NCBI server. The annotation files will then be converted to GTF format in the following scripting processes.

## 3.1 - Download Sequence and Annotation Files
Note: The current command-line tool from NCBI which allows downloading of datasets does not support downloading of annotation files for viral genomes in the NCBI nucleotide database. The `datasets download genome` tool currently only accepts genome assemblies, for which there are only a handful of human viruses (mostly influenza segments). The dedicated virus tool, `datasets download virus genome` does not offer annotation files as an option for download. This may change at some point, however a workaround is outlined below: 

NCBI Virus - Find list of 'complete' nucleotides for viruses with a human host.

Selection parameters on NCBI Virus:
Host = Human
Complete Nucleotides
Sequence Length > 1800

Retrieve the accession list from NCBI Virus, then split the list into chunks.
Use the accession lists to download sequence and annotation files from NCBI. For genomes collected from the GenBank database, only GFF3 format annotation files will be available.

To improve download speeds, save an NCBI API key to a file and export it as a global variable which the Edirect suite of tools will use automatically.

```bash
# Get API key from saved text file and export to global environment
ncbi_api_key_file="02_data/reference/NCBI_API_KEY"
export NCBI_API_KEY=$( < $ncbi_api_key_file)

accession_list_file="02_data/reference/virome_accession_list.acc"

bash "01_source/get_virome_ref.sh" \
    $accession_list_file
```

Clean the annotation file, removing unnecessary header lines. This is required to ensure that the conversion to gtf file format runs cleanly.
```bash
annotation_files_dir="02_data/reference/virome_ref/downloads/annotation_files"

bash "01_source/clean_annotation_files.sh" \
    $annotation_files_dir
```

Some records will include a GFF3 file to accompany the sequence file, but there won't be any features within the genome. These records will be ignored and not compiled into the reference database.

## 3.2 - Convert GFF3 files
Run annotation conversion script to convert the GFF3 format to GTF2.2 (see http://mblab.wustl.edu/GTF22.html).
In addition, handle the annotation of circular genomes which have features that overrun the length of the linearly-represented geneome sequence.
```bash
annotation_files_dir="02_data/reference/virome_ref/downloads/annotation_files"
sequence_files_dir="02_data/reference/virome_ref/downloads/sequence_files"

bash "01_source/convert_viral_annotation.sh" \
    $annotation_files_dir \
    $sequence_files_dir
```

## 3.3 - Summarize Viral Database
Create a summary of the viral species and individual genes covered in the viral database.
This requires the sql file for the R package Taxonomizr to be downloaded.
```bash
ref_annotation_file="02_data/reference/virome_ref/virome_annotation_converted.gtf"
sql_file="01_source/taxonomizr/accessionTaxa.sql"

Rscript "01_source/summarize_viral_database.r" \
    $ref_annotation_file \
    $sql_file

```

A good check of the file is to `grep` all lines with 'CDS' and look at the attributes to see that the transcript IDs are unique and that the gene_ids make sense.

Note: Some of the records downloaded from NCBI will have a single 'region' line in their GFF3 file. These will result in an error thrown by the 'cat' command, because the script will not process any annotation file which does not contain feature lines. In this case, the errors may be ignored and the result will just omit these genomes which have not been properly annotated.

## 3.4 - Indexing Viral Genomes
Index the reference viral genomes for use with STAR alignment
```bash
ref_genome="02_data/reference/virome_ref/virome_sequences_converted.fna"
ref_annotation="02_data/reference/virome_ref/virome_annotation_converted.gtf"

bash "01_source/index_viral_ref.sh" \
    $ref_genome \
    $ref_annotation
```

# 4 - Alignment to Viral Genomes
```bash
unaligned_read_file_dir="02_data/processed/unaligned"
index_dir="02_data/reference/virome_ref/virome_ref_index"

bash "01_source/align_viral.sh" \
    $unaligned_read_file_dir \
    $index_dir
```

## 4.1 - Counting Viral Transcripts
```bash
aligned_reads_dir="02_data/processed/viral_aligned"
viral_ref_annotation_file="02_data/reference/virome_ref/virome_annotation_converted.gtf"

bash "01_source/count_viral_tx.sh" \
	$aligned_reads_dir \
	$viral_ref_annotation_file
```

## 4.2 - Clean Viral Count Report
Clean the count data in R and prepare for further processing steps.

In the counts file:
- Chr is the <seqname> as defined in the GTF2.2 format.
```bash
viral_tx_counts_file="02_data/processed/viral_tx_counts.txt"

Rscript "01_source/clean_viral_count_data.r" \
    $viral_counts_file
```

# 5 - Analysis
## Combine and Prepare Data for Analysis
```bash
clinical_data_file="02_data/raw/clinicalData.txt"
human_tx_counts_file="02_data/processed/cleaned_human_tx_counts.rds"
viral_tx_counts_file="02_data/processed/cleaned_viral_tx_counts.rds"

RScript "01_source/prepare_data.r"
```

## Run Analysis and Create Figures

The analysis code is documented in a separate workbook, located at: 01_source/analysis.rmd
