#' Forecast accuracy metrics for load curves
#'
#' Compute NMAE, NRMSE, sMAPE and MASE between observed and predicted
#' load curves, as in the posters.
#'
#' @param truth Numeric vector or matrix of observed values.
#' @param pred  Numeric vector or matrix of predicted values, same shape.
#' @param seasonal_period Seasonal period for the naive benchmark in
#'   the MASE denominator (for daily curves with half hourly sampling,
#'   a value of 48 is appropriate).
#'
#' @return A named list with elements `nmae`, `nrmse`, `smape`, `mase`.
#' @export
elcf4r_metrics <- function(truth, pred, seasonal_period = NULL) {
  truth <- as.numeric(truth)
  pred  <- as.numeric(pred)
  stopifnot(length(truth) == length(pred))
  n <- length(truth)
  
  mae  <- mean(abs(truth - pred), na.rm = TRUE)
  rmse <- sqrt(mean((truth - pred)^2, na.rm = TRUE))
  
  rng <- max(truth, na.rm = TRUE) - min(truth, na.rm = TRUE)
  nmae <- mae / rng
  nrmse <- rmse / rng
  
  smape <- mean(
    2 * abs(pred - truth) / (abs(truth) + abs(pred) + 1e-8),
    na.rm = TRUE
  )
  
  if (!is.null(seasonal_period)) {
    # naive seasonal: Y_{t} = Y_{t - m}
    if (n <= seasonal_period) {
      mase <- NA_real_
    } else {
      naive_err <- abs(truth[(seasonal_period + 1):n] -
                         truth[1:(n - seasonal_period)])
      mase <- mae / mean(naive_err, na.rm = TRUE)
    }
  } else {
    mase <- NA_real_
  }
  
  list(
    nmae = nmae,
    nrmse = nrmse,
    smape = smape,
    mase = mase
  )
}
