#' Forecasting Individual Electricity Load Curves
#'
#' `elcf4R` provides methods and supporting workflows for day-ahead forecasting
#' of individual electricity load curves. The current package surface includes
#' Kernel Wavelet Functional models, clustered KWF, GAM, MARS and LSTM
#' estimators, dataset adapters for iFlex, StoreNet, Low Carbon London and
#' REFIT, scaffolded download/read support for IDEAL and GX, helpers to build
#' daily segments, and rolling-origin benchmarking utilities.
#'
"_PACKAGE"

#' @importFrom graphics barplot
#' @importFrom stats xtabs
#' @useDynLib elcf4R, .registration = TRUE
#' @importFrom Rcpp sourceCpp evalCpp
NULL
