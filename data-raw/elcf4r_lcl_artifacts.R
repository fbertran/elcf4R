# Build shipped Low Carbon London example and benchmark datasets.
#
# This script is not run on CRAN. Execute it manually from the package root
# after the raw LCL file has been placed at `data-raw/LCL_2013.csv`.

if (!requireNamespace("usethis", quietly = TRUE)) {
  stop("Package `usethis` is required to save package datasets.")
}

source(file.path("data-raw", "elcf4r_data_raw_api.R"))
api <- elcf4r_data_raw_api()

lcl_path <- file.path("data-raw", "LCL_2013.csv")
if (!file.exists(lcl_path)) {
  stop("Cannot find raw LCL data at ", lcl_path)
}

lcl_header <- names(data.table::fread(lcl_path, nrows = 0L, showProgress = FALSE))
candidate_ids <- utils::head(setdiff(lcl_header, "DateTime"), 40L)

lcl_panel <- api$elcf4r_read_lcl(
  path = lcl_path,
  ids = candidate_ids
)
lcl_index <- api$elcf4r_build_benchmark_index(
  lcl_panel,
  carry_cols = "dataset"
)

days_per_id <- table(lcl_index$entity_id)
example_ids <- utils::head(names(days_per_id[days_per_id >= 14L]), 2L)
train_days <- 56L
test_days <- 7L
required_days <- train_days + test_days
windowed_index <- api$slice_benchmark_index(
  lcl_index,
  required_days = required_days,
  entity_ids = names(days_per_id[days_per_id >= required_days]),
  anchor = "last"
)
thermo_ids <- unlist(
  lapply(
    split(windowed_index, windowed_index$entity_id),
    function(idx) {
      id <- unique(idx$entity_id)[[1L]]
      cutoff_dates <- sort(idx$date)[train_days:(nrow(idx) - 1L)]
      ok_all <- all(
        vapply(
          cutoff_dates,
          function(cutoff) {
            info <- api$elcf4r_classify_thermosensitivity(
              lcl_panel[
                lcl_panel$entity_id == id & lcl_panel$date <= cutoff,
                ,
                drop = FALSE
              ]
            )
            identical(info$status[[1L]], "ok") && isTRUE(info$thermosensitive[[1L]])
          },
          logical(1)
        )
      )
      if (ok_all) id else NA_character_
    }
  ),
  use.names = FALSE
)
thermo_ids <- thermo_ids[!is.na(thermo_ids)]
benchmark_ids <- utils::head(intersect(unique(windowed_index$entity_id), thermo_ids), 10L)

if (length(example_ids) < 1L || length(benchmark_ids) < 1L) {
  stop("Could not find enough complete LCL cohorts for shipped artifacts.")
}

example_keys <- unlist(
  lapply(
    example_ids,
    function(id) {
      utils::head(lcl_index$day_key[lcl_index$entity_id == id], 14L)
    }
  ),
  use.names = FALSE
)

elcf4r_lcl_example <- lcl_panel[
  paste(lcl_panel$entity_id, lcl_panel$date, sep = "__") %in% example_keys,
]

benchmark_methods <- c("gam", "mars", "kwf", "kwf_clustered")
if (isTRUE(api$lstm_backend_available())) {
  benchmark_methods <- c(benchmark_methods, "lstm")
}

benchmark_name <- paste0(
  "lcl_30min_",
  length(benchmark_ids),
  "_ids_56_train_7_test_",
  length(benchmark_methods),
  "_methods"
)

lcl_benchmark <- api$elcf4r_benchmark(
  panel = lcl_panel[lcl_panel$entity_id %in% benchmark_ids, , drop = FALSE],
  benchmark_index = windowed_index[windowed_index$entity_id %in% benchmark_ids, , drop = FALSE],
  methods = benchmark_methods,
  entity_ids = benchmark_ids,
  train_days = train_days,
  test_days = test_days,
  benchmark_name = benchmark_name,
  dataset = "lcl",
  use_temperature = FALSE,
  include_predictions = FALSE,
  seed = 1L,
  thermosensitivity_panel = lcl_panel[lcl_panel$entity_id %in% benchmark_ids, , drop = FALSE],
  method_args = list(
    kwf_clustered = list(
      wavelet = "la12",
      use_mean_correction = TRUE,
      max_clusters = 6L,
      nstart = 20L
    ),
    lstm = list(
      lookback_days = 1L,
      units = 4L,
      epochs = 2L,
      batch_size = 4L,
      verbose = 0L
    )
  )
)

elcf4r_lcl_benchmark_results <- lcl_benchmark$results
rownames(elcf4r_lcl_benchmark_results) <- NULL

usethis::use_data(
  elcf4r_lcl_example,
  elcf4r_lcl_benchmark_results,
  compress = "xz",
  overwrite = TRUE
)
