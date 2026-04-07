# Build a shipped benchmark-results dataset for iFlex.
#
# This script is not run on CRAN. Execute it manually from the package root
# after `data-raw/elcf4r_iflex_subsets.R` has created
# `data/elcf4r_iflex_benchmark_index.rda`.

if (!requireNamespace("usethis", quietly = TRUE)) {
  stop("Package `usethis` is required to save package datasets.")
}

preprocess_env <- new.env(parent = globalenv())
sys.source(file.path("R", "preprocess_segments.R"), envir = preprocess_env)
sys.source(file.path("R", "elcf4r_calendar_groups.R"), envir = preprocess_env)
sys.source(file.path("R", "elcf4r_fit_gam.R"), envir = preprocess_env)
sys.source(file.path("R", "elcf4r_fit_mars.R"), envir = preprocess_env)
sys.source(file.path("R", "elcf4r_fit_kwf.R"), envir = preprocess_env)
sys.source(file.path("R", "elcf4r_classify_thermosensitivity.R"), envir = preprocess_env)
sys.source(file.path("R", "elcf4r_kwf_clusters.R"), envir = preprocess_env)
sys.source(file.path("R", "elcf4r_fit_kwf_clustered.R"), envir = preprocess_env)
sys.source(file.path("R", "elcf4r_fit_lstm.R"), envir = preprocess_env)
sys.source(file.path("R", "model_predict.R"), envir = preprocess_env)
sys.source(file.path("R", "metrics.R"), envir = preprocess_env)
sys.source(file.path("R", "elcf4r_benchmark.R"), envir = preprocess_env)

elcf4r_read_iflex <- get("elcf4r_read_iflex", envir = preprocess_env)
elcf4r_benchmark <- get("elcf4r_benchmark", envir = preprocess_env)
lstm_backend_available <- get(".elcf4r_lstm_backend_available", envir = preprocess_env)

benchmark_index_path <- file.path("data", "elcf4r_iflex_benchmark_index.rda")
if (!file.exists(benchmark_index_path)) {
  stop(
    "Cannot find ", benchmark_index_path,
    ". Run data-raw/elcf4r_iflex_subsets.R first."
  )
}

load(benchmark_index_path)

cohort_size <- 15L
train_days <- 28L
test_days <- 7L

benchmark_methods <- c("gam", "mars", "kwf", "kwf_clustered")
if (isTRUE(lstm_backend_available())) {
  benchmark_methods <- c(benchmark_methods, "lstm")
}
benchmark_name <- paste0(
  "iflex_hourly_",
  cohort_size,
  "_ids_",
  train_days,
  "_train_",
  test_days,
  "_test_",
  length(benchmark_methods),
  "_methods"
)

iflex_panel_full <- elcf4r_read_iflex(
  path = file.path("data-raw", "iFlex")
)

benchmark_obj <- elcf4r_benchmark(
  panel = iflex_panel_full,
  benchmark_index = elcf4r_iflex_benchmark_index,
  methods = benchmark_methods,
  cohort_size = cohort_size,
  train_days = train_days,
  test_days = test_days,
  benchmark_name = benchmark_name,
  dataset = "iflex",
  use_temperature = TRUE,
  include_predictions = FALSE,
  thermosensitivity_panel = iflex_panel_full,
  method_args = list(
    kwf_clustered = list(
      wavelet = "la12",
      use_mean_correction = TRUE,
      max_clusters = 10L,
      nstart = 30L
    ),
    lstm = list(
      lookback_days = 1L,
      units = 8L,
      epochs = 4L,
      batch_size = 4L,
      verbose = 0L
    )
  )
)

elcf4r_iflex_benchmark_results <- benchmark_obj$results
rownames(elcf4r_iflex_benchmark_results) <- NULL

usethis::use_data(
  elcf4r_iflex_benchmark_results,
  compress = "xz",
  overwrite = TRUE
)
