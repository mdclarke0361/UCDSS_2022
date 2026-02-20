#
rm(list=ls())
pdf(NULL)

# Initialize the R env, get path variables for output.
source("01_source/initialize_script.r")

#
suppressPackageStartupMessages({
  library(tidyverse)
  library(purrr)
  library(jsonlite)
})

conflict_prefer_all("dplyr", quiet = TRUE)
conflicts_prefer(base::setdiff)

# Read arguments
args <- commandArgs(trailingOnly = TRUE)
human_gene_counts_file <- file.path(PROJECT_DIR, args[1])
human_annotation_report <- file.path(PROJECT_DIR, args[2])

# Assign name to output files
cleaned_human_gene_counts <- file.path(PROCESSED_DATA_DIR, "cleaned_human_gene_counts.rds")
human_fragment_metadata <- file.path(REPORT_DIR, "human_alignment_fragment_metadata.rds")

#
human_gene_counts <- read_tsv(
  file = human_gene_counts_file,
  skip = 1 # Skip file metadata
)

# Convert the jsonl report to a tibble
annotation_report <- stream_in(
  file(human_annotation_report)
  ) |>
  as_tibble()

# Correct column names
corrected_colnames <- human_gene_counts |>
  rename(
    gene_name = Geneid,
    chr = Chr,
    start = Start,
    end = End,
    strand = Strand,
    length = Length
  ) |>
  # Remove the path from all sample names
  rename_with(
    ~ str_remove(.x, ".*/"),
    .cols = 7:last_col()
  ) |>
  # Remove file extension from all sample names
  rename_with(
    ~ str_remove(.x, ".bam"),
    .cols = 7:last_col()
  )

# Duplicated chromosome records indicate multiple intragenic alignments
# Remove duplicated values but record number of multiples
deduplicated_values <- corrected_colnames |>
  mutate(
    chr_list = strsplit(chr, split = ";"),
    fragment_count = lengths(chr_list),
    chr_acc = map_chr(chr_list, first),
    .after = gene_name
  ) |>
  # Remove unorganized accession lists
  select(
    !c(chr_list, chr)
  ) |>
  # Use the annotation report to replace chromosome accessions with numbers
  left_join(
    select(
      annotation_report,
      chr = chrName,
      chr_acc = refseqAccession
    )
  ) |>
  select(
    !c(chr_acc)
  ) |>
  relocate(
    chr,
    .before = 1
  )

# Split the counts from metadata information regarding individual fragments
gene_counts <- deduplicated_values |>
  select(
    ! c(start, end, strand)
  )

fragment_metadata <- deduplicated_values |>
  select(
    gene_name,
    chr,
    fragment_count,
    start,
    end,
    strand,
    length
  )

# Save files
write_rds(
  gene_counts,
  file = cleaned_human_gene_counts
)

write_rds(
  fragment_metadata,
  file = human_fragment_metadata
)