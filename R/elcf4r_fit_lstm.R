#' Fit an LSTM model for daily load curves
#'
#' The LSTM implementation uses one or more previous daily curves to predict the
#' next daily curve. When `use_temperature = TRUE` and `temp_mean` is available
#' in `covariates`, the daily mean temperature is added as a second input
#' feature repeated across the within-day time steps.
#'
#' @param segments Matrix or data frame of past daily load curves
#'   (rows are days, columns are time points).
#' @param covariates Optional data frame with one row per training day.
#' @param use_temperature Logical. If `TRUE`, use `temp_mean` from
#'   `covariates` as an additional input feature when available.
#' @param lookback_days Number of past daily curves used as one training input.
#' @param units Number of hidden units in the LSTM layer.
#' @param epochs Number of training epochs.
#' @param batch_size Batch size used in `keras3::fit()`.
#' @param validation_split Validation split passed to `keras3::fit()`.
#' @param seed Optional integer seed passed to TensorFlow. When `NULL`, the
#'   current backend RNG state is used.
#' @param verbose Verbosity level passed to `keras3::fit()` and `predict()`.
#'
#' @return An object of class `elcf4r_model` with `method = "lstm"`.
#' @export
#' @examples
#' if (interactive() &&
#'     requireNamespace("keras3", quietly = TRUE) &&
#'     requireNamespace("tensorflow", quietly = TRUE) &&
#'     suppressWarnings(
#'       tryCatch(
#'         utils::getFromNamespace("is_keras_available", "keras3")(),
#'         error = function(e) FALSE
#'       )
#'     )) {
#'   id1 <- subset(
#'     elcf4r_iflex_example,
#'     entity_id == unique(elcf4r_iflex_example$entity_id)[1]
#'   )
#'   daily <- elcf4r_build_daily_segments(id1)
#'   fit <- elcf4r_fit_lstm(
#'     segments = daily$segments[1:10, ],
#'     covariates = daily$covariates[1:10, ],
#'     use_temperature = TRUE,
#'     epochs = 1,
#'     units = 4,
#'     batch_size = 2,
#'     verbose = 0
#'   )
#'   length(predict(fit))
#' }
elcf4r_fit_lstm <- function(
    segments,
    covariates = NULL,
    use_temperature = FALSE,
    lookback_days = 1L,
    units = 16L,
    epochs = 10L,
    batch_size = 8L,
    validation_split = 0,
    seed = NULL,
    verbose = 0L
) {
  if (!requireNamespace("keras3", quietly = TRUE)) {
    stop("Package `keras3` is required for `elcf4r_fit_lstm()`.")
  }
  if (!requireNamespace("tensorflow", quietly = TRUE)) {
    stop("Package `tensorflow` is required for `elcf4r_fit_lstm()`.")
  }
  if (!.elcf4r_lstm_backend_available()) {
    stop(
      "A working Keras/TensorFlow backend is not available. ",
      "Install TensorFlow for the Python environment used by R before ",
      "calling `elcf4r_fit_lstm()`."
    )
  }

  segments <- .elcf4r_as_numeric_matrix(segments, "segments")
  lookback_days <- as.integer(lookback_days)
  units <- as.integer(units)
  epochs <- as.integer(epochs)
  batch_size <- as.integer(batch_size)
  verbose <- as.integer(verbose)
  if (!is.null(seed)) {
    seed <- as.integer(seed)[1L]
    if (!is.finite(seed)) {
      stop("`seed` must be NULL or a finite integer.")
    }
  }

  if (lookback_days < 1L) {
    stop("`lookback_days` must be at least 1.")
  }
  if (nrow(segments) <= lookback_days) {
    stop("Not enough training days for the requested `lookback_days`.")
  }

  if (!is.null(covariates)) {
    covariates <- as.data.frame(covariates, stringsAsFactors = FALSE)
    if (nrow(covariates) != nrow(segments)) {
      stop("`covariates` must have one row per training segment.")
    }
  }

  arrays <- .elcf4r_make_lstm_training_arrays(
    segments = segments,
    covariates = covariates,
    use_temperature = use_temperature,
    lookback_days = lookback_days
  )

  if (!is.null(seed)) {
    tensorflow::set_random_seed(seed)
  }
  keras3::clear_session()

  model <- keras3::keras_model_sequential()
  model$add(
    keras3::layer_input(
      shape = c(arrays$input_steps, arrays$n_features)
    )
  )
  model$add(keras3::layer_lstm(units = units))
  model$add(keras3::layer_dense(units = ncol(segments)))
  model$compile(
    optimizer = "adam",
    loss = "mse"
  )
  history <- model$fit(
    x = arrays$x,
    y = arrays$y,
    epochs = epochs,
    batch_size = min(batch_size, dim(arrays$x)[1]),
    validation_split = validation_split,
    verbose = verbose
  )

  last_input_array <- .elcf4r_make_lstm_prediction_array(
    segments = utils::tail(segments, lookback_days),
    covariates = if (is.null(covariates)) NULL else utils::tail(covariates, lookback_days),
    use_temperature = use_temperature,
    temp_center = arrays$temp_center,
    temp_scale = arrays$temp_scale,
    load_center = arrays$load_center,
    load_scale = arrays$load_scale
  )

  structure(
    list(
      model = model,
      history = history,
      method = "lstm",
      use_temperature = use_temperature,
      lookback_days = lookback_days,
      n_time = ncol(segments),
      input_steps = arrays$input_steps,
      n_features = arrays$n_features,
      load_center = arrays$load_center,
      load_scale = arrays$load_scale,
      temp_center = arrays$temp_center,
      temp_scale = arrays$temp_scale,
      last_input_array = last_input_array
    ),
    class = "elcf4r_model"
  )
}

.elcf4r_lstm_backend_available <- function() {
  if (!requireNamespace("keras3", quietly = TRUE)) {
    return(FALSE)
  }
  if (!requireNamespace("tensorflow", quietly = TRUE)) {
    return(FALSE)
  }

  if (identical(Sys.getenv("RETICULATE_PYTHON"), "")) {
    if (requireNamespace("reticulate", quietly = TRUE) &&
        reticulate::virtualenv_exists("r-tensorflow")) {
      Sys.setenv(
        RETICULATE_PYTHON = reticulate::virtualenv_python("r-tensorflow")
      )
    } else {
      python_path <- Sys.which("python3")
      if (nzchar(python_path)) {
        Sys.setenv(RETICULATE_PYTHON = python_path)
      }
    }
  }

  isTRUE(
    suppressWarnings(
      tryCatch(
        utils::getFromNamespace("is_keras_available", "keras3")(),
        error = function(e) FALSE
      )
    )
  )
}

.elcf4r_make_lstm_training_arrays <- function(
    segments,
    covariates,
    use_temperature,
    lookback_days
) {
  n_days <- nrow(segments)
  n_time <- ncol(segments)
  n_samples <- n_days - lookback_days

  load_center <- mean(segments, na.rm = TRUE)
  load_scale <- stats::sd(as.numeric(segments), na.rm = TRUE)
  if (!is.finite(load_scale) || load_scale <= 0) {
    load_scale <- 1
  }
  scaled_segments <- (segments - load_center) / load_scale

  temp_feature <- NULL
  temp_center <- NA_real_
  temp_scale <- NA_real_
  if (
    isTRUE(use_temperature) &&
    !is.null(covariates) &&
    "temp_mean" %in% names(covariates)
  ) {
    temp_feature <- as.numeric(covariates[["temp_mean"]])
    temp_center <- mean(temp_feature, na.rm = TRUE)
    temp_scale <- stats::sd(temp_feature, na.rm = TRUE)
    if (!is.finite(temp_scale) || temp_scale <= 0) {
      temp_scale <- 1
    }
    temp_feature <- (temp_feature - temp_center) / temp_scale
  }

  n_features <- if (is.null(temp_feature)) 1L else 2L
  input_steps <- n_time * lookback_days
  x <- array(
    0,
    dim = c(n_samples, input_steps, n_features)
  )
  y <- matrix(0, nrow = n_samples, ncol = n_time)

  for (i in seq_len(n_samples)) {
    input_idx <- i:(i + lookback_days - 1L)
    input_load <- as.vector(t(scaled_segments[input_idx, , drop = FALSE]))
    input_mat <- matrix(input_load, ncol = 1L)

    if (!is.null(temp_feature)) {
      input_temp <- rep(temp_feature[input_idx], each = n_time)
      input_mat <- cbind(input_mat, input_temp)
    }

    x[i, , ] <- input_mat
    y[i, ] <- scaled_segments[i + lookback_days, ]
  }

  list(
    x = x,
    y = y,
    input_steps = input_steps,
    n_features = n_features,
    load_center = load_center,
    load_scale = load_scale,
    temp_center = temp_center,
    temp_scale = temp_scale
  )
}

.elcf4r_make_lstm_prediction_array <- function(
    segments,
    covariates,
    use_temperature,
    temp_center,
    temp_scale,
    load_center,
    load_scale
) {
  segments <- .elcf4r_as_numeric_matrix(segments, "segments")
  n_time <- ncol(segments)
  load_values <- as.vector(t((segments - load_center) / load_scale))
  input_mat <- matrix(load_values, ncol = 1L)

  if (
    isTRUE(use_temperature) &&
    !is.null(covariates) &&
    "temp_mean" %in% names(covariates)
  ) {
    temp_values <- as.numeric(covariates[["temp_mean"]])
    if (!is.finite(temp_scale) || temp_scale <= 0) {
      temp_scale <- 1
    }
    temp_values <- (temp_values - temp_center) / temp_scale
    input_mat <- cbind(input_mat, rep(temp_values, each = n_time))
  }

  array(
    input_mat,
    dim = c(1L, nrow(input_mat), ncol(input_mat))
  )
}
