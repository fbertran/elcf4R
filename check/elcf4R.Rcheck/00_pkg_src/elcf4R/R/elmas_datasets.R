#' Toy subset of ELMAS hourly cluster profiles
#'
#' A compact subset of the public ELMAS dataset containing hourly load profiles
#' for 3 commercial or industrial load clusters over 70 days. The object is
#' intended for lightweight examples and tests that demonstrate time-series or
#' segment-based workflows without shipping the full source archive.
#'
#' @name elcf4r_elmas_toy
#' @docType data
#' @keywords datasets
#'
#' @format A tibble with 5,040 rows and 3 variables:
#' \describe{
#'   \item{time}{Hourly timestamp.}
#'   \item{cluster_id}{Cluster identifier, one of 3 retained ELMAS clusters.}
#'   \item{load_mwh}{Cluster load in MWh.}
#' }
#'
#' @source Public ELMAS dataset, reduced with package `data-raw` scripts for
#'   examples and tests.
NULL
