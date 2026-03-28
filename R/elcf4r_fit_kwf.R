#' Fit a KWF model for daily load curves
#'
#' @param segments Matrix or data frame of past daily load curves
#'   (rows are days, columns are time points).
#' @param covariates Data frame with day level covariates
#'   (calendar, temperature, cluster labels).
#' @param use_temperature Logical. If `TRUE`, clustering accounts
#'   for thermo sensitivity.
#' @param wavelet Character string naming the wavelet family.
#'
#' @return An `elcf4r_model` with `method = "kwf"`.
#' @export
elcf4r_fit_kwf <- function(
    segments,
    covariates,
    use_temperature = FALSE,
    wavelet = "la8"
) {
  stop("KWF C++ implementation to be added.")
}