# tests/testthat/test-kwf.R

test_that("elcf4r_fit_kwf returns an object with expected structure", {
  set.seed(123)
  seg <- matrix(rnorm(5 * 4), nrow = 5, ncol = 4)
  covariates <- data.frame(
    dow = factor(c("Mon", "Tue", "Wed", "Thu", "Fri")),
    temp_mean = c(4, 6, 7, 5, 3)
  )
  target_covariates <- data.frame(
    dow = factor("Thu", levels = levels(covariates$dow)),
    temp_mean = 5.5
  )

  fit <- elcf4r_fit_kwf(
    segments = seg,
    covariates = covariates,
    target_covariates = target_covariates,
    use_temperature = TRUE
  )

  expect_s3_class(fit, "elcf4r_model")
  expect_equal(fit$method, "kwf")
  expect_equal(fit$n_segments, 5L)
  expect_equal(fit$n_time, 4L)
  expect_length(fit$fitted_curve, 4L)
  expect_length(fit$weights, 5L)
})

test_that("predict.elcf4r_model works for kwf objects", {
  set.seed(1)
  seg <- matrix(rnorm(3 * 10), nrow = 3, ncol = 10)
  fit <- elcf4r_fit_kwf(segments = seg, covariates = data.frame(temp_mean = 1:3))
  pred <- predict(fit)
  expect_equal(length(pred), 10L)
})

test_that("elcf4r_fit_lstm returns a model when keras3 is available", {
  skip_if_not_installed("keras3")
  skip_if_not_installed("tensorflow")
  old_managed <- Sys.getenv("RETICULATE_USE_MANAGED_VENV", unset = NA_character_)
  old_python <- Sys.getenv("RETICULATE_PYTHON", unset = NA_character_)
  on.exit({
    if (is.na(old_managed)) {
      Sys.unsetenv("RETICULATE_USE_MANAGED_VENV")
    } else {
      Sys.setenv(RETICULATE_USE_MANAGED_VENV = old_managed)
    }
    if (is.na(old_python)) {
      Sys.unsetenv("RETICULATE_PYTHON")
    } else {
      Sys.setenv(RETICULATE_PYTHON = old_python)
    }
  }, add = TRUE)
  Sys.setenv(RETICULATE_USE_MANAGED_VENV = "false")
  if (requireNamespace("reticulate", quietly = TRUE) &&
      reticulate::virtualenv_exists("r-tensorflow")) {
    Sys.setenv(
      RETICULATE_PYTHON = reticulate::virtualenv_python("r-tensorflow")
    )
  }
  skip_if_not(.elcf4r_lstm_backend_available())

  set.seed(1)
  seg <- matrix(rnorm(8 * 6), nrow = 8, ncol = 6)
  covariates <- data.frame(temp_mean = seq_len(8))

  fit <- elcf4r_fit_lstm(
    segments = seg,
    covariates = covariates,
    use_temperature = TRUE,
    units = 4L,
    epochs = 1L,
    batch_size = 2L,
    verbose = 0L
  )

  expect_s3_class(fit, "elcf4r_model")
  expect_equal(fit$method, "lstm")
  expect_equal(length(predict(fit)), 6L)
})
