# Build a small toy dataset `elcf4r_elmas_toy` from the public
# ELMAS dataset archive. The result is suitable for inclusion
# in the elcf4R package under data/elcf4r_elmas_toy.rda.
#
# Expected workflow
#   1. Download ELMAS_dataset.zip from figshare to data-raw/
#   2. Run this script from the package root
#   3. Commit the resulting .rda file under data/
#
# This script is not run on CRAN.

if (!requireNamespace("usethis", quietly = TRUE)) {
  stop("Package `usethis` is required to build data objects.")
}

if (!requireNamespace("readr", quietly = TRUE)) {
  stop("Package `readr` is required to read ELMAS csv files.")
}

if (!requireNamespace("dplyr", quietly = TRUE)) {
  stop("Package `dplyr` is required to manipulate the data.")
}

if (!requireNamespace("tidyr", quietly = TRUE)) {
  stop("Package `tidyr` is required to reshape the data.")
}

# Path to the local copy of the ELMAS archive.
# Adjust if you store it in a different directory.
zip_path <- file.path("data-raw", "ELMAS_dataset.zip")

if (!file.exists(zip_path)) {
  stop("Cannot find ELMAS_dataset.zip at ", zip_path)
}

tmp_dir <- tempfile("elmas_zip_")
dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)

utils::unzip(zipfile = zip_path, exdir = tmp_dir)

# The archive contains a directory ELMAS_dataset with several csv files.
# We use the time series with 18 typical profiles.
ts_path <- file.path(tmp_dir, "ELMAS_dataset", "Time_series_18_clusters.csv")

if (!file.exists(ts_path)) {
  stop("Cannot find Time_series_18_clusters.csv inside the archive.")
}

# File uses semicolon as field separator and comma as decimal mark.
# We let readr handle this locale explicitly.

elmas_ts <- readr::read_delim(
  file = ts_path,
  delim = ";",
  locale = readr::locale(decimal_mark = ","),
  show_col_types = FALSE,
  trim_ws = TRUE
)

# The first column contains the time stamp.
# Other columns correspond to the 18 clusters identified by the authors.
# We normalise column names so that clusters are "cl_1", "cl_2", ..., "cl_18".

if (ncol(elmas_ts) < 2L) {
  stop("Unexpected structure in Time_series_18_clusters.csv")
}

# Rename first column to "time". Other columns as cl_1 ... cl_k.
old_names <- names(elmas_ts)
names(elmas_ts)[1L] <- "time"
k <- ncol(elmas_ts) - 1L
new_cluster_names <- paste0("cl_", seq_len(k))
names(elmas_ts)[-1L] <- new_cluster_names

# Convert time to POSIXct. Original format is "YYYY MM DD HH:MM:SS"
# represented as ISO character.

elmas_ts$time <- as.POSIXct(elmas_ts$time, tz = "UTC")

# For a compact toy dataset we keep
#   - the first 70 days of data
#   - three clusters (for example cl_1, cl_5, cl_12)
#
# We use row index to keep the first 7 * 24 hourly points.

n_per_day <- 24L
n_days <- 70L
n_keep <- n_per_day * n_days

if (nrow(elmas_ts) < n_keep) {
  stop("ELMAS time series has fewer rows than expected.")
}

keep_rows <- seq_len(n_keep)
keep_clusters <- c("cl_1", "cl_5", "cl_12")

missing_clusters <- setdiff(keep_clusters, names(elmas_ts))
if (length(missing_clusters) > 0L) {
  stop("Requested clusters not found in ELMAS data: ",
       paste(missing_clusters, collapse = ", "))
}

elmas_small <- elmas_ts[keep_rows, c("time", keep_clusters)]

# Reshape to long format for easier use in examples:
# one row per time and per cluster.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

elcf4r_elmas_toy <- elmas_small %>%
  tidyr::pivot_longer(
    cols = dplyr::starts_with("cl_"),
    names_to = "cluster_id",
    values_to = "load_mwh"
  ) %>%
  dplyr::arrange(cluster_id, time)

# Save as package data.
usethis::use_data(
  elcf4r_elmas_toy,
#  name = "elcf4r_elmas_toy",
  compress = "xz",
  overwrite = TRUE
)
