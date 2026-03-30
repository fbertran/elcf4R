#' Fit a simple KWF-style model for daily load curves
#'
#' The current implementation is a pragmatic forecasting baseline: it computes a
#' weighted average of past daily curves, with optional reweighting by day of
#' week and temperature similarity. This keeps the package benchmarkable while a
#' fuller kernel-wavelet implementation is still under development.
#'
#' @param segments Matrix or data frame of past daily load curves
#'   (rows are days, columns are time points).
#' @param covariates Optional data frame with one row per training day. If
#'   present, `dow` and `temp_mean` are used when available.
#' @param target_covariates Optional one-row data frame describing the target
#'   day to forecast.
#' @param use_temperature Logical. If `TRUE`, temperature similarity is used
#'   when `temp_mean` is available in both `covariates` and `target_covariates`.
#' @param wavelet Character string naming the wavelet family.
#' @param weights Optional numeric vector of non-negative weights of length
#'   equal to the number of rows in `segments`.
#' @param recency_decay Non-negative recency coefficient applied when
#'   `weights` is not supplied. Larger values emphasize recent days more.
#' @param temperature_bandwidth Optional positive bandwidth for temperature
#'   similarity weighting. If `NULL`, it is inferred from the training
#'   `temp_mean` values.
#'
#' @return An object of class `elcf4r_model` with `method = "kwf"`.
#' @export
#' @examples
#' id1 <- subset(
#'   elcf4r_iflex_example,
#'   entity_id == unique(elcf4r_iflex_example$entity_id)[1]
#' )
#' daily <- elcf4r_build_daily_segments(id1, carry_cols = "participation_phase")
#' fit <- elcf4r_fit_kwf(
#'   segments = daily$segments[1:10, ],
#'   covariates = daily$covariates[1:10, ],
#'   target_covariates = daily$covariates[11, , drop = FALSE],
#'   use_temperature = TRUE
#' )
#' length(predict(fit))
elcf4r_fit_kwf <- function(
    segments,
    covariates = NULL,
    target_covariates = NULL,
    use_temperature = FALSE,
    wavelet = "la8",
    weights = NULL,
    recency_decay = 0.05,
    temperature_bandwidth = NULL
) {
  segments <- .elcf4r_as_numeric_matrix(segments, "segments")
  n_segments <- nrow(segments)
  n_time <- ncol(segments)

  if (!is.null(covariates)) {
    covariates <- as.data.frame(covariates, stringsAsFactors = FALSE)
    if (nrow(covariates) != n_segments) {
      stop("`covariates` must have one row per training segment.")
    }
  }

  if (!is.null(target_covariates)) {
    target_covariates <- as.data.frame(target_covariates, stringsAsFactors = FALSE)
    if (nrow(target_covariates) != 1L) {
      stop("`target_covariates` must have exactly one row.")
    }
  }

  if (!is.null(weights)) {
    if (!is.numeric(weights) || length(weights) != n_segments) {
      stop("`weights` must be numeric with length equal to `nrow(segments)`.")
    }
    final_weights <- as.numeric(weights)
  } else {
    recency_decay <- as.numeric(recency_decay)
    if (!is.finite(recency_decay) || recency_decay < 0) {
      stop("`recency_decay` must be a non-negative number.")
    }
    final_weights <- exp((seq_len(n_segments) - n_segments) * recency_decay)
  }

  if (!is.null(covariates) && !is.null(target_covariates)) {
    final_weights <- .elcf4r_apply_kwf_covariate_weights(
      weights = final_weights,
      covariates = covariates,
      target_covariates = target_covariates,
      use_temperature = use_temperature,
      temperature_bandwidth = temperature_bandwidth
    )
  }

  fitted_curve <- .elcf4r_weighted_average(segments, final_weights)

  structure(
    list(
      method = "kwf",
      fitted_curve = fitted_curve,
      n_segments = n_segments,
      n_time = n_time,
      wavelet = wavelet,
      use_temperature = use_temperature,
      weights = final_weights,
      covariates = covariates,
      target_covariates = target_covariates
    ),
    class = "elcf4r_model"
  )
}

.elcf4r_apply_kwf_covariate_weights <- function(
    weights,
    covariates,
    target_covariates,
    use_temperature,
    temperature_bandwidth
) {
  adjusted <- as.numeric(weights)

  if ("dow" %in% names(covariates) && "dow" %in% names(target_covariates)) {
    dow_match <- as.character(covariates[["dow"]]) ==
      as.character(target_covariates[["dow"]][[1L]])
    adjusted <- adjusted * ifelse(dow_match, 2, 1)
  }

  if (
    isTRUE(use_temperature) &&
    "temp_mean" %in% names(covariates) &&
    "temp_mean" %in% names(target_covariates)
  ) {
    train_temp <- as.numeric(covariates[["temp_mean"]])
    target_temp <- as.numeric(target_covariates[["temp_mean"]][[1L]])

    if (is.finite(target_temp)) {
      temp_diff <- abs(train_temp - target_temp)
      if (is.null(temperature_bandwidth)) {
        temperature_bandwidth <- stats::sd(train_temp, na.rm = TRUE)
      }
      if (!is.finite(temperature_bandwidth) || temperature_bandwidth <= 0) {
        temperature_bandwidth <- 1
      }
      temp_weights <- exp(-(temp_diff / temperature_bandwidth)^2)
      temp_weights[!is.finite(temp_weights)] <- 1
      adjusted <- adjusted * temp_weights
    }
  }

  adjusted
}

.elcf4r_as_numeric_matrix <- function(x, arg) {
  if (is.data.frame(x)) {
    x <- as.matrix(x)
  }
  if (!is.matrix(x) || !is.numeric(x)) {
    stop("`", arg, "` must be a numeric matrix or data frame.")
  }
  if (nrow(x) < 1L || ncol(x) < 1L) {
    stop("`", arg, "` must have at least one row and one column.")
  }
  storage.mode(x) <- "double"
  x
}

.elcf4r_weighted_average <- function(segments, weights) {
  weights <- as.numeric(weights)
  if (length(weights) != nrow(segments)) {
    stop("`weights` length must match the number of rows in `segments`.")
  }
  if (any(!is.finite(weights)) || any(weights < 0)) {
    stop("`weights` must be finite and non-negative.")
  }
  if (sum(weights) <= 0) {
    stop("Sum of `weights` must be positive.")
  }

  if (exists("kwf_weighted_average_cpp", mode = "function")) {
    return(kwf_weighted_average_cpp(segments, weights))
  }

  colSums(segments * weights) / sum(weights)
}
