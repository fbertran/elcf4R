# Build shipped REFIT example and benchmark datasets.
#
# This script is not run on CRAN. Execute it manually from the package root
# after the raw REFIT files have been placed under `data-raw/`.

if (!requireNamespace("usethis", quietly = TRUE)) {
  stop("Package `usethis` is required to save package datasets.")
}

source(file.path("data-raw", "elcf4r_data_raw_api.R"))
api <- elcf4r_data_raw_api()

refit_path <- "data-raw"
if (!file.exists(file.path(refit_path, "CLEAN_House1.csv"))) {
  stop("Cannot find raw REFIT data at ", refit_path)
}

candidate_house_ids <- c(
  "CLEAN_House1", "CLEAN_House2", "CLEAN_House3",
  "CLEAN_House4", "CLEAN_House5", "CLEAN_House11"
)

refit_panel <- api$elcf4r_read_refit(
  path = refit_path,
  house_ids = candidate_house_ids,
  channels = "Aggregate",
  resolution_minutes = 15L,
  agg_fun = "mean"
)
refit_index <- api$elcf4r_build_benchmark_index(
  refit_panel,
  carry_cols = c("dataset", "house_id", "channel")
)

days_per_id <- table(refit_index$entity_id)
train_days <- 56L
test_days <- 7L
required_days <- train_days + test_days
windowed_index <- api$slice_benchmark_index(
  refit_index,
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
              refit_panel[
                refit_panel$entity_id == id & refit_panel$date <= cutoff,
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
benchmark_ids <- utils::head(intersect(unique(windowed_index$entity_id), thermo_ids), 3L)

if (length(benchmark_ids) < 1L) {
  stop("Need at least one REFIT household with sufficient coverage for the shipped benchmark.")
}

example_ids <- utils::head(names(days_per_id[days_per_id >= 14L]), 2L)
example_keys <- unlist(
  lapply(
    example_ids,
    function(id) utils::head(refit_index$day_key[refit_index$entity_id == id], 14L)
  ),
  use.names = FALSE
)
elcf4r_refit_example <- refit_panel[
  paste(refit_panel$entity_id, refit_panel$date, sep = "__") %in% example_keys,
]

benchmark_methods <- c("gam", "mars", "kwf", "kwf_clustered")
if (isTRUE(api$lstm_backend_available())) {
  benchmark_methods <- c(benchmark_methods, "lstm")
}

benchmark_name <- paste0(
  "refit_15min_",
  length(benchmark_ids),
  "_ids_56_train_7_test_",
  length(benchmark_methods),
  "_methods"
)

refit_benchmark <- api$elcf4r_benchmark(
  panel = refit_panel[refit_panel$entity_id %in% benchmark_ids, , drop = FALSE],
  benchmark_index = windowed_index[windowed_index$entity_id %in% benchmark_ids, , drop = FALSE],
  methods = benchmark_methods,
  entity_ids = benchmark_ids,
  train_days = train_days,
  test_days = test_days,
  benchmark_name = benchmark_name,
  dataset = "refit",
  use_temperature = FALSE,
  include_predictions = FALSE,
  seed = 1L,
  thermosensitivity_panel = refit_panel[refit_panel$entity_id %in% benchmark_ids, , drop = FALSE],
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

elcf4r_refit_benchmark_results <- refit_benchmark$results
rownames(elcf4r_refit_benchmark_results) <- NULL

usethis::use_data(
  elcf4r_refit_example,
  elcf4r_refit_benchmark_results,
  compress = "xz",
  overwrite = TRUE
)
