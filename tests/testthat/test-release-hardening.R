make_release_panel_fixture <- function() {
  timestamps <- seq(
    as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
    by = "hour",
    length.out = 15L * 24L
  )
  time_index <- rep(seq_len(24L), 15L)
  day_index <- rep(0:14, each = 24L)

  raw <- data.frame(
    id = rep("home_a", length(timestamps)),
    timestamp = timestamps,
    load = 1.2 + 0.3 * sin(2 * pi * time_index / 24) + 0.08 * day_index + time_index / 120,
    temp = rep(seq(4, 12, length.out = 24L), 15L) + rep(seq(-1, 1, length.out = 15L), each = 24L),
    stringsAsFactors = FALSE
  )

  elcf4r_normalize_panel(
    data = raw,
    id_col = "id",
    timestamp_col = "timestamp",
    load_col = "load",
    temp_col = "temp",
    dataset = "fixture",
    resolution_minutes = 60L,
    tz = "UTC"
  )
}

test_that("shipped example datasets expose the normalized core schema", {
  shipped_examples <- list(
    iflex = elcf4r_iflex_example,
    storenet = elcf4r_storenet_example,
    lcl = elcf4r_lcl_example,
    refit = elcf4r_refit_example
  )
  core_cols <- c(
    "dataset", "entity_id", "timestamp", "date", "time_index",
    "y", "temp", "dow", "month", "resolution_minutes"
  )

  for (nm in names(shipped_examples)) {
    expect_true(all(core_cols %in% names(shipped_examples[[nm]])), info = nm)
  }
})

test_that("shipped benchmark datasets share the benchmark result schema", {
  shipped_results <- list(
    iflex = elcf4r_iflex_benchmark_results,
    storenet = elcf4r_storenet_benchmark_results,
    lcl = elcf4r_lcl_benchmark_results,
    refit = elcf4r_refit_benchmark_results
  )
  expected_cols <- c(
    "benchmark_name", "dataset", "entity_id", "method", "test_date",
    "train_start", "train_end", "train_days", "test_points",
    "use_temperature", "thermosensitive", "thermosensitivity_status",
    "thermosensitivity_ratio", "fit_seconds", "status", "error_message",
    "nmae", "nrmse", "smape", "mase"
  )

  for (nm in names(shipped_results)) {
    expect_equal(names(shipped_results[[nm]]), expected_cols, info = nm)
  }
})

test_that("GAM and MARS expose stable elcf4r_model outputs", {
  panel <- make_release_panel_fixture()
  train <- subset(panel, date < sort(unique(panel$date))[11])
  test <- subset(panel, date == sort(unique(panel$date))[11])
  x_cols <- c("y", "time_index", "dow", "month", "temp")

  fit_gam <- elcf4r_fit_gam(train[, x_cols], use_temperature = TRUE)
  pred_gam <- predict(fit_gam, newdata = test[, x_cols])

  expect_s3_class(fit_gam, "elcf4r_model")
  expect_identical(fit_gam$method, "gam")
  expect_true(isTRUE(fit_gam$use_temperature))
  expect_length(pred_gam, nrow(test))
  expect_true(all(is.finite(pred_gam)))

  fit_mars <- elcf4r_fit_mars(train[, x_cols], use_temperature = TRUE)
  pred_mars <- predict(fit_mars, newdata = test[, x_cols])

  expect_s3_class(fit_mars, "elcf4r_model")
  expect_identical(fit_mars$method, "mars")
  expect_true(isTRUE(fit_mars$use_temperature))
  expect_length(pred_mars, nrow(test))
  expect_true(all(is.finite(pred_mars)))
})

test_that("LSTM exposes stable elcf4r_model outputs when backend is available", {
  skip_if_not_installed("reticulate")
  skip_if_not_installed("keras3")
  skip_if_not_installed("tensorflow")
  skip_if_not(reticulate::virtualenv_exists("r-tensorflow"))
  elcf4r_use_tensorflow_env(virtualenv = "r-tensorflow", required = TRUE)
  skip_if_not(
    getFromNamespace(".elcf4r_lstm_backend_available", "elcf4R")(),
    "Keras/TensorFlow backend not available"
  )

  panel <- make_release_panel_fixture()
  daily <- elcf4r_build_daily_segments(panel)

  fit <- elcf4r_fit_lstm(
    segments = daily$segments[1:10, ],
    covariates = daily$covariates[1:10, , drop = FALSE],
    use_temperature = TRUE,
    epochs = 1L,
    units = 4L,
    batch_size = 2L,
    verbose = 0L
  )
  pred <- predict(fit)

  expect_s3_class(fit, "elcf4r_model")
  expect_identical(fit$method, "lstm")
  expect_true(isTRUE(fit$use_temperature))
  expect_equal(fit$n_time, ncol(daily$segments))
  expect_length(pred, ncol(daily$segments))
  expect_true(all(is.finite(pred)))
})
