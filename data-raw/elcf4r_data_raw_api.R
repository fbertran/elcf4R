elcf4r_data_raw_api <- function() {
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

  list(
    elcf4r_read_iflex = get("elcf4r_read_iflex", envir = preprocess_env),
    elcf4r_read_storenet = get("elcf4r_read_storenet", envir = preprocess_env),
    elcf4r_read_lcl = get("elcf4r_read_lcl", envir = preprocess_env),
    elcf4r_read_refit = get("elcf4r_read_refit", envir = preprocess_env),
    elcf4r_classify_thermosensitivity = get("elcf4r_classify_thermosensitivity", envir = preprocess_env),
    elcf4r_build_benchmark_index = get("elcf4r_build_benchmark_index", envir = preprocess_env),
    elcf4r_benchmark = get("elcf4r_benchmark", envir = preprocess_env),
    slice_benchmark_index = get(".elcf4r_slice_benchmark_index", envir = preprocess_env),
    lstm_backend_available = get(".elcf4r_lstm_backend_available", envir = preprocess_env)
  )
}
