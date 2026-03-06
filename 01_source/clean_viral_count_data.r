#
rm(list=ls())
pdf(NULL)

# Initialize the R env, get path variables for output.
source("01_source/initialize_script.r")

#
suppressPackageStartupMessages({
  library(tidyverse)
  library(purrr)
})

conflict_prefer_all("dplyr", quiet = TRUE)
conflicts_prefer(base::setdiff)

# Read arguments
args <- commandArgs(trailingOnly = TRUE)
viral_tx_counts_file <- file.path(PROJECT_DIR, args[1])

# Assign name to output files
cleaned_viral_tx_counts_file <- file.path(PROCESSED_DATA_DIR, "cleaned_viral_tx_counts.rds")

#
viral_tx_counts <- read_tsv(
  file = viral_tx_counts_file,
  skip = 1
)

# Correct column names
counts <- viral_tx_counts |>
  rename(
    gene_id = Geneid,
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
    ~ str_remove(.x, "\\..*"),
    .cols = 7:last_col()
  ) |>
  rename_with(
    ~ str_replace(.x, "_Aligned", ""),
    .cols = 7:last_col()
  ) |>
  rename_with(
    ~ str_replace(.x, "-", "_"),
    .cols = 7:last_col()
  ) |>
  #
  mutate(
    chr = str_split_i(chr, ";", 1),
    start = str_split_i(start, ";", 1),
    end = str_split_i(end, ";", 1),
    strand = str_split_i(strand, ";", 1)
)

# Save files
write_rds(
  counts,
  file = cleaned_viral_tx_counts_file
)