# data-raw/elcf4r_elmas_demo.R
#
# This script downloads the public ELMAS dataset and builds
# a small demo object named `elcf4r_elmas_demo` that can be
# stored inside the package with `usethis::use_data`.
#
# The script is not executed on CRAN. Run it manually from the
# package root when you want to refresh the demo data.

if (!requireNamespace("usethis", quietly = TRUE)) {
  stop("Package `usethis` is required to build data objects.")
}

if (!requireNamespace("readr", quietly = TRUE)) {
  stop("Package `readr` is required to read ELMAS csv files.")
}

# Optional but convenient
if (!requireNamespace("dplyr", quietly = TRUE)) {
  stop("Package `dplyr` is required to create the demo subset.")
}

# Location of the ELMAS archive on figshare.
# Dataset page
#   https://figshare.com/articles/dataset/ELMAS_dataset/23889780
# Direct download link for the main zip archive:
#   https://figshare.com/ndownloader/files/41895786

elmas_zip_url <- "https://figshare.com/ndownloader/files/41895786"

tmp_dir <- tempfile("elmas_raw_")
dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
zip_path <- file.path(tmp_dir, "elmas.zip")

utils::download.file(elmas_zip_url, destfile = zip_path, mode = "wb")

files <- utils::unzip(zip_path, exdir = tmp_dir)

csv_files <- files[grepl("\\.csv$", files)]
if (length(csv_files) == 0L) {
  stop("No csv file found in the unzipped ELMAS archive.")
}

message("Using csv file: ", csv_files[10L])

elmas_raw <- readr::read_csv2(csv_files[10L], show_col_types = FALSE)

# Create a compact demo object.
# The exact column names depend on the official ELMAS release.
# Inspect `names(elmas_raw)` once and update the three column
# names below if needed.
#
# Example guess:
#   activity_label, subscribed_power_class, date_time, load_mw

suppressPackageStartupMessages({
  library(dplyr)
})

# Replace these names if they differ in the actual csv
activity_col <- "activity_label"
datetime_col <- "date_time"
load_col <- "load_mw"

required_cols <- c(activity_col, datetime_col, load_col)
missing_cols <- setdiff(required_cols, names(elmas_raw))
if (length(missing_cols) > 0L) {
  stop("Required columns missing in ELMAS csv: ",
       paste(missing_cols, collapse = ", "))
}

# Choose a few activities
activity_values <- sort(unique(elmas_raw[[activity_col]]))
if (length(activity_values) < 3L) {
  stop("Unexpected structure in ELMAS data: not enough activities.")
}

keep_activities <- activity_values[seq_len(min(3L, length(activity_values)))]

elcf4r_elmas_demo <- elmas_raw %>%
  dplyr::filter(.data[[activity_col]] %in% keep_activities) %>%
  dplyr::mutate(
    date_time = .data[[datetime_col]],
    load = .data[[load_col]]
  ) %>%
  dplyr::select(
    activity = .data[[activity_col]],
    date_time,
    load
  ) %>%
  dplyr::arrange(activity, date_time)

# Downsample in time to keep the object small.
# For example keep one point every four hours.

elcf4r_elmas_demo <- elcf4r_elmas_demo %>%
  dplyr::group_by(activity) %>%
  dplyr::slice(seq(1L, dplyr::n(), by = 4L)) %>%
  dplyr::ungroup()

# Save into data/ with high compression.
usethis::use_data(elcf4r_elmas_demo,
                  name = "elcf4r_elmas_demo",
                  compress = "xz",
                  overwrite = TRUE)
