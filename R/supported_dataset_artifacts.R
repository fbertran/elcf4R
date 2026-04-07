#' StoreNet example panel for package examples
#'
#' A compact normalized panel extracted from the local StoreNet household file
#' `H6_W.csv`. The object contains a small set of complete 1-minute household
#' days and is intended for examples and lightweight benchmarking workflows.
#'
#' @name elcf4r_storenet_example
#' @docType data
#' @keywords datasets
#'
#' @format A data frame with normalized panel columns plus StoreNet-specific
#' fields:
#' \describe{
#'   \item{dataset}{Dataset label, always `"storenet"`.}
#'   \item{entity_id}{Household identifier derived from the file name.}
#'   \item{timestamp,date,time_index,y,temp,dow,month,resolution_minutes}{Common
#'     normalized panel fields.}
#'   \item{discharge_w,charge_w,production_w}{Battery and production fields from
#'     the source file in watts.}
#'   \item{state_of_charge_pct}{Battery state of charge in percent.}
#'   \item{source_file}{Source CSV file name.}
#' }
#'
#' @source Public StoreNet raw file `H6_W.csv`, reduced with
#'   `data-raw/elcf4r_storenet_artifacts.R`.
NULL

#' StoreNet benchmark results for shipped forecasting methods
#'
#' Saved rolling-origin benchmark results for the shipped methods on the local
#' StoreNet household example. The benchmark is derived from complete 1-minute
#' household days and reports NMAE, NRMSE, sMAPE and MASE for every shipped
#' row. The clustered KWF variant is only included when the shipped StoreNet
#' cohort is classified as thermosensitive.
#'
#' @name elcf4r_storenet_benchmark_results
#' @docType data
#' @keywords datasets
#'
#' @format A data frame with the same benchmark-result schema as
#' `elcf4r_iflex_benchmark_results`.
#'
#' @source Derived from the local StoreNet raw file with
#'   `data-raw/elcf4r_storenet_artifacts.R`.
NULL

#' Low Carbon London example panel for package examples
#'
#' A compact normalized panel extracted from a small group of households in the
#' Low Carbon London dataset. The object contains complete 30-minute days and is
#' intended for examples and lightweight benchmarking workflows.
#'
#' @name elcf4r_lcl_example
#' @docType data
#' @keywords datasets
#'
#' @format A data frame with normalized panel fields:
#' \describe{
#'   \item{dataset}{Dataset label, always `"lcl"`.}
#'   \item{entity_id}{Low Carbon London household identifier.}
#'   \item{timestamp,date,time_index,y,temp,dow,month,resolution_minutes}{Common
#'     normalized panel fields.}
#' }
#'
#' @source Public LCL raw file `LCL_2013.csv`, reduced with
#'   `data-raw/elcf4r_lcl_artifacts.R`.
NULL

#' Low Carbon London benchmark results for shipped forecasting methods
#'
#' Saved rolling-origin benchmark results for the shipped methods on a fixed
#' Low Carbon London cohort of households. The benchmark is based on 30-minute
#' load curves and reports NMAE, NRMSE, sMAPE and MASE.
#'
#' @name elcf4r_lcl_benchmark_results
#' @docType data
#' @keywords datasets
#'
#' @format A data frame with the same benchmark-result schema as
#' `elcf4r_iflex_benchmark_results`.
#'
#' @source Derived from the local LCL raw file with
#'   `data-raw/elcf4r_lcl_artifacts.R`.
NULL

#' REFIT example panel for package examples
#'
#' A compact normalized panel extracted from the REFIT cleaned dataset after
#' resampling to 15-minute resolution. The object contains complete days for one
#' house and is intended for examples and lightweight benchmarking workflows.
#'
#' @name elcf4r_refit_example
#' @docType data
#' @keywords datasets
#'
#' @format A data frame with normalized panel columns plus REFIT-specific
#' fields:
#' \describe{
#'   \item{dataset}{Dataset label, always `"refit"`.}
#'   \item{entity_id}{Entity identifier, here the aggregate household channel.}
#'   \item{timestamp,date,time_index,y,temp,dow,month,resolution_minutes}{Common
#'     normalized panel fields.}
#'   \item{house_id}{REFIT house identifier derived from the file name.}
#'   \item{channel}{Load channel name, for example `"Aggregate"`.}
#'   \item{unix}{Minimum Unix timestamp within the resampling bucket.}
#'   \item{issues}{Maximum issues flag within the resampling bucket.}
#' }
#'
#' @source Public REFIT cleaned raw files, reduced with
#'   `data-raw/elcf4r_refit_artifacts.R`.
NULL

#' REFIT benchmark results for shipped forecasting methods
#'
#' Saved rolling-origin benchmark results for the shipped methods on the REFIT
#' example cohort after resampling to 15-minute resolution. The benchmark
#' reports NMAE, NRMSE, sMAPE and MASE.
#'
#' @name elcf4r_refit_benchmark_results
#' @docType data
#' @keywords datasets
#'
#' @format A data frame with the same benchmark-result schema as
#' `elcf4r_iflex_benchmark_results`.
#'
#' @source Derived from the local REFIT raw files with
#'   `data-raw/elcf4r_refit_artifacts.R`.
NULL
