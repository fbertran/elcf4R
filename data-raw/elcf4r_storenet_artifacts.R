# Build shipped StoreNet example and benchmark datasets.
#
# This script is not run on CRAN. Execute it manually from the package root
# after the raw StoreNet household file has been placed at `data-raw/H6_W.csv`.

if (!requireNamespace("usethis", quietly = TRUE)) {
  stop("Package `usethis` is required to save package datasets.")
}

source(file.path("data-raw", "elcf4r_data_raw_api.R"))
api <- elcf4r_data_raw_api()

storenet_path <- "data-raw"
storenet_files <- list.files(
  storenet_path,
  pattern = "^H.*_W\\.csv$",
  full.names = TRUE
)
if (length(storenet_files) < 1L) {
  stop("Cannot find raw StoreNet household files under ", storenet_path)
}

storenet_panel <- api$elcf4r_read_storenet(storenet_path)
storenet_index <- api$elcf4r_build_benchmark_index(
  storenet_panel,
  carry_cols = c("dataset", "source_file")
)

if (nrow(storenet_index) < 7L) {
  stop("Need at least 7 complete StoreNet days to build the shipped artifacts.")
}

days_per_id <- table(storenet_index$entity_id)
example_ids <- utils::head(names(days_per_id[days_per_id >= 6L]), 2L)
example_keys <- unlist(
  lapply(
    example_ids,
    function(id) utils::head(storenet_index$day_key[storenet_index$entity_id == id], 6L)
  ),
  use.names = FALSE
)
elcf4r_storenet_example <- storenet_panel[
  paste(storenet_panel$entity_id, storenet_panel$date, sep = "__") %in% example_keys,
]

benchmark_methods <- c("gam", "mars", "kwf", "kwf_clustered")
if (isTRUE(api$lstm_backend_available())) {
  benchmark_methods <- c(benchmark_methods, "lstm")
}

thermo_info <- api$elcf4r_classify_thermosensitivity(storenet_panel)
if (!all(thermo_info$thermosensitive %in% TRUE)) {
  benchmark_methods <- setdiff(benchmark_methods, "kwf_clustered")
}

benchmark_name <- paste0(
  "storenet_1min_",
  length(unique(storenet_index$entity_id)),
  "_ids_5_train_2_test_",
  length(benchmark_methods),
  "_methods"
)

storenet_benchmark <- api$elcf4r_benchmark(
  panel = storenet_panel,
  benchmark_index = storenet_index,
  methods = benchmark_methods,
  entity_ids = unique(storenet_index$entity_id),
  train_days = 5L,
  test_days = 2L,
  benchmark_name = benchmark_name,
  dataset = "storenet",
  use_temperature = FALSE,
  include_predictions = FALSE,
  thermosensitivity_panel = storenet_panel,
  method_args = list(
    kwf_clustered = list(
      wavelet = "la12",
      use_mean_correction = TRUE,
      max_clusters = 4L,
      nstart = 10L
    ),
    lstm = list(
      lookback_days = 1L,
      units = 4L,
      epochs = 2L,
      batch_size = 2L,
      verbose = 0L
    )
  )
)

elcf4r_storenet_benchmark_results <- storenet_benchmark$results
rownames(elcf4r_storenet_benchmark_results) <- NULL

usethis::use_data(
  elcf4r_storenet_example,
  elcf4r_storenet_benchmark_results,
  compress = "xz",
  overwrite = TRUE
)
