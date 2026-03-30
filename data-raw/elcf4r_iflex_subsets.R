# Build compact iFlex subsets for examples and benchmarks.
#
# This script is not run on CRAN. Execute it manually from the package root
# after the raw iFlex files have been placed under data-raw/iFlex/.

if (!requireNamespace("usethis", quietly = TRUE)) {
  stop("Package `usethis` is required to save package datasets.")
}

preprocess_env <- new.env(parent = globalenv())
sys.source(file.path("R", "preprocess_segments.R"), envir = preprocess_env)
elcf4r_read_iflex <- get("elcf4r_read_iflex", envir = preprocess_env)
elcf4r_build_daily_segments <- get("elcf4r_build_daily_segments", envir = preprocess_env)

iflex_dir <- file.path("data-raw", "iFlex")
if (!dir.exists(iflex_dir)) {
  stop("Cannot find raw iFlex data at ", iflex_dir)
}

carry_cols <- c("dataset", "participation_phase", "price_signal")

iflex_panel <- elcf4r_read_iflex(iflex_dir)
iflex_segments <- elcf4r_build_daily_segments(
  data = iflex_panel,
  carry_cols = carry_cols
)

iflex_index <- iflex_segments$covariates[
  ,
  c(
    "day_key",
    "entity_id",
    "date",
    "dow",
    "month",
    "temp_mean",
    "temp_min",
    "temp_max",
    "participation_phase",
    "price_signal",
    "n_points"
  )
]

# Example subset:
#   - first 3 participants with at least 14 complete days
#   - first 14 complete days per selected participant
days_per_id <- table(iflex_index$entity_id)
example_ids <- names(days_per_id[days_per_id >= 14L])[seq_len(min(3L, sum(days_per_id >= 14L)))]
example_keys <- unlist(
  lapply(
    example_ids,
    function(id) {
      head(iflex_index$day_key[iflex_index$entity_id == id], 14L)
    }
  ),
  use.names = FALSE
)

elcf4r_iflex_example <- iflex_panel[
  paste(iflex_panel$entity_id, iflex_panel$date, sep = "__") %in% example_keys,
]

# Benchmark index:
#   - all complete participant-days
#   - compact metadata that can be joined to saved benchmark scores later
elcf4r_iflex_benchmark_index <- iflex_index

usethis::use_data(
  elcf4r_iflex_example,
  elcf4r_iflex_benchmark_index,
  compress = "xz",
  overwrite = TRUE
)
