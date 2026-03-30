#' iFlex example panel for package examples
#'
#' A compact hourly electricity-demand panel extracted from the public iFlex
#' dataset. The object contains 14 complete days for each of 3 participants and
#' is intended for examples, tests and lightweight vignettes.
#'
#' @name elcf4r_iflex_example
#' @docType data
#' @keywords datasets
#' 
#' @format A data frame with 1,008 rows and 16 variables:
#' \describe{
#'   \item{dataset}{Dataset label, always `"iflex"`.}
#'   \item{entity_id}{Participant identifier.}
#'   \item{timestamp}{Hourly UTC timestamp.}
#'   \item{date}{Calendar date of the observation.}
#'   \item{time_index}{Within-day hourly index from 1 to 24.}
#'   \item{y}{Hourly electricity demand in kWh.}
#'   \item{temp}{Outdoor temperature in degrees Celsius.}
#'   \item{dow}{Day of week.}
#'   \item{month}{Month as a two-digit factor.}
#'   \item{resolution_minutes}{Sampling resolution in minutes.}
#'   \item{participation_phase}{Experiment phase from the source dataset.}
#'   \item{price_signal}{Experimental price-signal label, when available.}
#'   \item{price_nok_kwh}{Experimental electricity price in NOK per kWh.}
#'   \item{temp24}{Lagged 24-hour temperature feature from the source file.}
#'   \item{temp48}{Lagged 48-hour temperature feature from the source file.}
#'   \item{temp72}{Lagged 72-hour temperature feature from the source file.}
#' }
#'
#' @source Public iFlex raw file `data_hourly.csv`, reduced with
#'   `data-raw/elcf4r_iflex_subsets.R`.
NULL

#' iFlex benchmark index of complete participant-days
#'
#' A compact index of complete days derived from the public iFlex hourly panel.
#' Each row represents one participant-day with enough metadata to define
#' deterministic benchmark cohorts without shipping the full raw panel.
#'
#' @name elcf4r_iflex_benchmark_index
#' @docType data
#' @keywords datasets
#'
#' @format A data frame with 563,150 rows and 11 variables:
#' \describe{
#'   \item{day_key}{Unique key built as `entity_id__date`.}
#'   \item{entity_id}{Participant identifier.}
#'   \item{date}{Calendar date.}
#'   \item{dow}{Day of week.}
#'   \item{month}{Month as a two-digit factor.}
#'   \item{temp_mean}{Mean daily outdoor temperature in degrees Celsius.}
#'   \item{temp_min}{Minimum daily outdoor temperature in degrees Celsius.}
#'   \item{temp_max}{Maximum daily outdoor temperature in degrees Celsius.}
#'   \item{participation_phase}{Experiment phase from the source dataset.}
#'   \item{price_signal}{Experimental price-signal label, when available.}
#'   \item{n_points}{Number of hourly samples retained for the day.}
#' }
#'
#' @source Public iFlex raw file `data_hourly.csv`, reduced with
#'   `data-raw/elcf4r_iflex_subsets.R`.
NULL

#' iFlex benchmark results for shipped forecasting methods
#'
#' Saved benchmark results for a deterministic rolling-origin evaluation on a
#' subset of the iFlex data. The shipped results use 10 participant IDs, a
#' 28-day training window and 5 one-day test forecasts per participant. The
#' current shipped benchmark includes the operational `gam`, `mars`, `kwf` and
#' `lstm` wrappers.
#'
#' @name elcf4r_iflex_benchmark_results
#' @docType data
#' @keywords datasets
#'
#' @format A data frame with 200 rows and 17 variables:
#' \describe{
#'   \item{benchmark_name}{Identifier of the benchmark design.}
#'   \item{dataset}{Dataset label, always `"iflex"`.}
#'   \item{entity_id}{Participant identifier.}
#'   \item{method}{Forecasting method: `gam`, `mars`, `kwf` or `lstm`.}
#'   \item{test_date}{Date of the forecast target day.}
#'   \item{train_start}{First day in the training window.}
#'   \item{train_end}{Last day in the training window.}
#'   \item{train_days}{Number of training days.}
#'   \item{test_points}{Number of hourly points in the target day.}
#'   \item{use_temperature}{Logical flag for temperature-aware fitting.}
#'   \item{fit_seconds}{Elapsed fit-and-predict time in seconds.}
#'   \item{status}{Benchmark execution status.}
#'   \item{error_message}{Error message when a fit failed.}
#'   \item{nmae}{Normalized mean absolute error.}
#'   \item{nrmse}{Normalized root mean squared error.}
#'   \item{smape}{Symmetric mean absolute percentage error.}
#'   \item{mase}{Mean absolute scaled error.}
#' }
#'
#' @source Derived from `elcf4r_iflex_benchmark_index` and the public iFlex raw
#'   file with `data-raw/elcf4r_iflex_benchmark_results.R`.
NULL
