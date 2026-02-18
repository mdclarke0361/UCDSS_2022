#
rm(list=ls())
pdf(NULL)

# Initialize the R env, get path variables for output.
source("01_source/initialize_script.r")

# Get logfile name
log_file <- assign_log_filename()

# Redirect output to the file and also keep it on the console
sink(file = log_file, split = TRUE)

#
suppressPackageStartupMessages({
  library(tidyverse)
  library(purrr)
})

conflict_prefer_all("dplyr", quiet = TRUE)
conflicts_prefer(base::setdiff)

# Read arguments
args <- commandArgs(trailingOnly = TRUE)
viral_counts_file <- file.path(project_dir, args[1])

# Assign name to output files
cleaned_viral_counts_file <- file.path(processed_data_dir, "viral_counts.rds")

#
viral_counts <- read_tsv(
  file = viral_counts_file,
  skip = 1
)

# Correct column names
viral_counts <- viral_counts |>
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
    ~ str_remove(.x, ".bam"),
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
  viral_counts,
  file = cleaned_viral_counts_file
)

# Stop redirecting output
sink()