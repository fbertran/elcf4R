#' Predict from an `elcf4r_model`
#'
#' @param object An `elcf4r_model` created by one of the package fit functions.
#' @param newdata Optional new data for methods that need it. For `gam` and
#'   `mars`, this should be a long-format data frame with the same predictor
#'   columns used for fitting. For `lstm`, `newdata` may be a matrix or data
#'   frame of recent daily segments, or a list with elements `segments` and
#'   optional `covariates`.
#' @param ... Unused, present for method compatibility.
#'
#' @return Numeric predictions. For KWF and LSTM this is a forecast daily curve.
#' @export
predict.elcf4r_model <- function(object, newdata = NULL, ...) {
  if (!inherits(object, "elcf4r_model") || is.null(object$method)) {
    stop("`object` must inherit from `elcf4r_model`.")
  }

  method <- object$method

  if (identical(method, "kwf")) {
    return(as.numeric(object$fitted_curve))
  }

  if (identical(method, "gam") || identical(method, "mars")) {
    if (is.null(newdata)) {
      stop("`newdata` is required to predict with method `", method, "`.")
    }
    return(as.numeric(stats::predict(object$model, newdata = newdata, ...)))
  }

  if (identical(method, "lstm")) {
    if (is.null(newdata)) {
      input_array <- object$last_input_array
    } else {
      input_array <- .elcf4r_lstm_newdata_array(object, newdata)
    }
    pred_scaled <- object$model$predict(input_array, verbose = 0)
    pred <- as.numeric(pred_scaled) * object$load_scale + object$load_center
    return(pred)
  }

  stop("Prediction for method `", method, "` is not implemented.")
}

.elcf4r_lstm_newdata_array <- function(object, newdata) {
  if (is.list(newdata) && !is.data.frame(newdata) && !is.matrix(newdata)) {
    segments <- newdata[["segments"]]
    covariates <- newdata[["covariates"]]
  } else {
    segments <- newdata
    covariates <- NULL
  }

  .elcf4r_make_lstm_prediction_array(
    segments = segments,
    covariates = covariates,
    use_temperature = object$use_temperature,
    temp_center = object$temp_center,
    temp_scale = object$temp_scale,
    load_center = object$load_center,
    load_scale = object$load_scale
  )
}
