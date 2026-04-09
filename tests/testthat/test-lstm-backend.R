test_that(".elcf4r_lstm_backend_available returns FALSE cleanly without keras3/tensorflow", {
  testthat::local_mocked_bindings(
    .elcf4r_keras3_available = function() FALSE,
    .elcf4r_tensorflow_available = function() FALSE,
    .package = "elcf4R"
  )

  expect_false(getFromNamespace(".elcf4r_lstm_backend_available", "elcf4R")())
})

test_that(".elcf4r_lstm_backend_available does not mutate RETICULATE_PYTHON", {
  old_python <- Sys.getenv("RETICULATE_PYTHON", unset = NA_character_)

  invisible(getFromNamespace(".elcf4r_lstm_backend_available", "elcf4R")())

  expect_identical(
    Sys.getenv("RETICULATE_PYTHON", unset = NA_character_),
    old_python
  )
})

test_that("elcf4r_use_tensorflow_env validates its selector arguments", {
  expect_error(
    elcf4r_use_tensorflow_env(),
    "Supply exactly one of `python` or `virtualenv`."
  )
  expect_error(
    elcf4r_use_tensorflow_env(python = "python", virtualenv = "r-tensorflow"),
    "Supply exactly one of `python` or `virtualenv`."
  )
})

test_that("elcf4r_use_tensorflow_env errors clearly without reticulate", {
  testthat::local_mocked_bindings(
    .elcf4r_reticulate_available = function() FALSE,
    .package = "elcf4R"
  )

  expect_error(
    elcf4r_use_tensorflow_env(python = "/usr/bin/python3"),
    "Package `reticulate` is required"
  )
})

test_that("elcf4r_use_tensorflow_env returns the selected virtualenv interpreter", {
  skip_if_not_installed("reticulate")
  skip_if_not(reticulate::virtualenv_exists("r-tensorflow"))

  expected <- normalizePath(
    reticulate::virtualenv_python("r-tensorflow"),
    winslash = "/",
    mustWork = FALSE
  )
  selected <- elcf4r_use_tensorflow_env(virtualenv = "r-tensorflow", required = TRUE)

  expect_identical(selected, expected)
})

test_that("elcf4r_use_tensorflow_env returns the selected python interpreter", {
  skip_if_not_installed("reticulate")
  skip_if_not(reticulate::virtualenv_exists("r-tensorflow"))

  python <- reticulate::virtualenv_python("r-tensorflow")
  expected <- normalizePath(python, winslash = "/", mustWork = FALSE)
  selected <- elcf4r_use_tensorflow_env(python = python, required = TRUE)

  expect_identical(selected, expected)
})

test_that("benchmark backend info does not force py_config when Python is uninitialized", {
  testthat::local_mocked_bindings(
    .elcf4r_reticulate_available = function() TRUE,
    .elcf4r_reticulate_py_available = function(initialize = FALSE) FALSE,
    .elcf4r_reticulate_py_config = function() stop("py_config should not be called"),
    .elcf4r_lstm_backend_available = function() FALSE,
    .package = "elcf4R"
  )

  out <- getFromNamespace(".elcf4r_benchmark_backend_info", "elcf4R")()

  expect_true(is.na(out$reticulate_python))
  expect_false(out$lstm_backend_available)
})
