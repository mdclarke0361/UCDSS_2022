# Initialize project scripts.

# Load package to get project directory
library(this.path)
library(conflicted)

SCRIPT_DIR <- this.dir()
PROJECT_DIR <- dirname(SCRIPT_DIR)

# Get path for project directories.
RAW_DATA_DIR <- file.path(PROJECT_DIR, "02_data/raw") # Input data, does not change
PROCESSED_DATA_DIR <- file.path(PROJECT_DIR, "02_data/processed") # Output Data from program
REF_DATA_DIR <- file.path(PROJECT_DIR, "02_data/reference") # Downloaded data for reference
FIGURE_DIR <- file.path(PROJECT_DIR, "03_results/figures") # Output figures
REPORT_DIR <- file.path(PROJECT_DIR, "03_results/reports") # Output reports (ex. QA/QC)
TABLE_DIR <- file.path(PROJECT_DIR, "03_results/tables") # Output tables
LOG_DIR <- file.path(PROJECT_DIR, "03_results/logs") # Output logs from program runs

# Create function to automatically assign a log filename
ASSIGN_LOG_FILENAME <- function() {
	script_name <- basename(this.path())
	script_basename <- sub("\\.[^.]*$", "", script_name)
	LOG_FILE <- file.path(LOG_DIR, paste0(script_basename, ".log"))
	return(LOG_FILE)
}

# Ensure all project directories exist
subdirs <- c(

    # Data directories
	RAW_DATA_DIR, PROCESSED_DATA_DIR, REF_DATA_DIR,
    # Results directories
	FIGURE_DIR, REPORT_DIR, TABLE_DIR, LOG_DIR

)

for (dir in subdirectories) {

    dir.create(dir, recursive = TRUE, showWarnings = FALSE)

}

# Set up of text colors for terminal output.
RED <- "\033[0;31m"
GREEN <- "\033[0;32m"
YELLOW <- "\033[0;33m"
NC <- "\033[0m"

# Set up colours for plotting
PLOT_COLOURS <- c(
    "#4A6990", "#A73030", "#79AF97",
    "#DF8F44", "#6A6599", "#374E55",
    "#B1746F", "#8A8B79", "#7AA6DC",
    "#616530", "#642822", "#9A5324",
    "#0B1948"
)
