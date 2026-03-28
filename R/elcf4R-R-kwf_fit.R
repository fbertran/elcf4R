# R/kwf_fit.R
#
# High level interface for the KWF model.
# At this stage the C plus plus core only implements a
# weighted average of past curves. This is already useful
# as a baseline functional kernel smoother.

#' Fit a simple KWF style model for daily load curves
#'
#' This function prepares the inputs for the C plus plus core
#' `kwf_weighted_average_cpp`. It treats each row of `segments`
#' as one daily curve and uses the supplied `weights` to form
#' a weighted average curve that can serve as a forecast.
#'
#' In later versions this function will call a full Kernel
#' Wavelet Functional implementation.
#'
#' @param segments Numeric matrix or data frame with one daily
#'   load curve per row and time points in columns.
#' @param weights Optional numeric vector of non negative
#'   weights of length equal to the number of rows in
#'   `segments`. If missing, uniform weights are used.
#'
#' @return An object of class `elcf4r_model` with fields
#'   `method`, `fitted_curve`, `n_segments` and `n_time`.
#' @export
#' @examples
#' set.seed(123)
#' seg <- matrix(rnorm(10 * 48), nrow = 10, ncol = 48)
#' fit_kwf <- elcf4r_fit_kwf(segments = seg)
#' length(fit_kwf$fitted_curve)
elcf4r_fit_kwf <- function(segments, weights = NULL) {
  if (is.data.frame(segments)) {
    segments <- as.matrix(segments)
  }
  if (!is.matrix(segments)) {
    stop("`segments` must be a numeric matrix or data frame.")
  }
  if (!is.numeric(segments)) {
    stop("`segments` must be numeric.")
  }
  if (nrow(segments) < 1L || ncol(segments) < 1L) {
    stop("`segments` must have at least one row and one column.")
  }

  n_segments <- nrow(segments)
  n_time <- ncol(segments)

  if (is.null(weights)) {
    weights <- rep(1.0, n_segments)
  } else {
    if (!is.numeric(weights)) {
      stop("`weights` must be numeric when supplied.")
    }
    if (length(weights) != n_segments) {
      stop("`weights` length must match number of rows in `segments`.")
    }
  }

  fitted_curve <- kwf_weighted_average_cpp(segments, weights)

  res <- list(
    method = "kwf",
    fitted_curve = fitted_curve,
    n_segments = n_segments,
    n_time = n_time
  )
  class(res) <- "elcf4r_model"
  res
}

#' Predict from a KWF style model
#'
#' For the current simple implementation, prediction just
#' returns the stored fitted average curve for any input.
#'
#' @param object An `elcf4r_model` created by
#'   `elcf4r_fit_kwf`.
#' @param newdata Ignored for now. Present for future
#'   extensions.
#' @param ... Unused, present for method compatibility.
#'
#' @return Numeric vector that represents the forecast curve.
#' @export
predict.elcf4r_model <- function(object, newdata = NULL, ...) {
  if (!is.list(object) || is.null(object$method)) {
    stop("`object` does not look like an `elcf4r_model`.")
  }
  if (identical(object$method, "kwf")) {
    return(object$fitted_curve)
  }
  stop("Prediction for method `", object$method, "` is not implemented yet.")
}
