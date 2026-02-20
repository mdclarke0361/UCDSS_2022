# Initialize project scripts.
library(this.path)
library(conflicted)

# Get path for project directory
script_dir <- here()
PROJECT_DIR <- dirname(script_dir)

# Ensure all project directories exist, if not, create them.
subdirectories <- c(
	"02_data/metadata", "02_data/processed", "02_data/raw", "02_data/reference",
	"03_results/figures", "03_results/reports", "03_results/tables", "03_results/logs"
)

for (dir in subdirectories) {

    dir.create(
        file.path(PROJECT_DIR, dir),
        recursive = TRUE,
        showWarnings = FALSE
    )

}

# Set variables to match repo file directory.
METADATA_DIR <- file.path(PROJECT_DIR, "02_data/metadata")
PROCESSED_DATA_DIR <- file.path(PROJECT_DIR, "02_data/processed")
RAW_DATA_DIR <- file.path(PROJECT_DIR, "02_data/raw")
REF_DATA_DIR <- file.path(PROJECT_DIR, "02_data/reference")
FIGURE_DIR <- file.path(PROJECT_DIR, "03_results/figures")
REPORT_DIR <- file.path(PROJECT_DIR, "03_results/reports")
TABLE_DIR <- file.path(PROJECT_DIR, "03_results/tables")
LOG_DIR <- file.path(PROJECT_DIR, "03_results/logs")

#
PLOT_COLOURS <- c(
    "#4A6990", "#A73030", "#79AF97",
    "#DF8F44", "#6A6599", "#374E55",
    "#B1746F", "#8A8B79", "#7AA6DC",
    "#616530", "#642822", "#9A5324",
    "#0B1948"
)
