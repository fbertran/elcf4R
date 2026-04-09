#' Classify thermosensitivity from daily load data
#'
#' Estimate thermosensitivity using the residential rule based on the
#' ratio between mean winter load and mean summer load.
#'
#' @param data Data frame containing at least an identifier, a date and a load
#'   column. Long-format panels are accepted and are aggregated to mean daily
#'   load before classification.
#' @param id_col Name of the entity identifier column.
#' @param date_col Name of the date column.
#' @param value_col Name of the load column.
#' @param threshold Ratio threshold above which the series is classified as
#'   thermosensitive. Defaults to `1.5`.
#' @param winter_months Integer vector of winter months.
#' @param summer_months Integer vector of summer months.
#'
#' @return A data frame with one row per entity and columns `winter_mean`,
#'   `summer_mean`, `ratio`, `thermosensitive`, and `status`.
#' @export
#'
#' @examples
#' example_ts <- data.frame(
#'   entity_id = rep("home_1", 4),
#'   date = as.Date(c("2024-01-10", "2024-01-11", "2024-07-10", "2024-07-11")),
#'   y = c(12, 11, 6, 5)
#' )
#' elcf4r_classify_thermosensitivity(example_ts)
elcf4r_classify_thermosensitivity <- function(
    data,
    id_col = "entity_id",
    date_col = "date",
    value_col = "y",
    threshold = 1.5,
    winter_months = c(12L, 1L, 2L),
    summer_months = c(6L, 7L, 8L)
) {
  stopifnot(is.data.frame(data))

  required_cols <- c(id_col, date_col, value_col)
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0L) {
    stop(
      "Missing required columns: ",
      paste(missing_cols, collapse = ", ")
    )
  }

  data <- data[, required_cols, drop = FALSE]
  data[[date_col]] <- as.Date(data[[date_col]])
  if (anyNA(data[[date_col]])) {
    stop("`date_col` must be coercible to `Date` without missing values.")
  }
  data[[value_col]] <- as.numeric(data[[value_col]])

  daily <- stats::aggregate(
    data[[value_col]],
    by = list(
      entity_id = as.character(data[[id_col]]),
      date = data[[date_col]]
    ),
    FUN = function(x) mean(x, na.rm = TRUE)
  )
  names(daily)[names(daily) == "x"] <- "daily_mean_load"
  daily$month_num <- as.integer(format(daily$date, "%m"))

  split_daily <- split(daily, daily$entity_id)
  out <- lapply(
    names(split_daily),
    function(id) {
      d <- split_daily[[id]]
      winter_vals <- d$daily_mean_load[d$month_num %in% winter_months]
      summer_vals <- d$daily_mean_load[d$month_num %in% summer_months]

      winter_mean <- if (length(winter_vals) > 0L) {
        mean(winter_vals, na.rm = TRUE)
      } else {
        NA_real_
      }
      summer_mean <- if (length(summer_vals) > 0L) {
        mean(summer_vals, na.rm = TRUE)
      } else {
        NA_real_
      }

      status <- "ok"
      ratio <- NA_real_
      thermosensitive <- NA

      if (length(winter_vals) == 0L && length(summer_vals) == 0L) {
        status <- "insufficient_seasonal_coverage"
      } else if (length(winter_vals) == 0L) {
        status <- "insufficient_winter_coverage"
      } else if (length(summer_vals) == 0L) {
        status <- "insufficient_summer_coverage"
      } else if (!is.finite(summer_mean) || summer_mean <= 0) {
        status <- "invalid_summer_mean"
      } else {
        ratio <- winter_mean / summer_mean
        thermosensitive <- isTRUE(ratio > threshold)
      }

      data.frame(
        entity_id = id,
        winter_mean = winter_mean,
        summer_mean = summer_mean,
        ratio = ratio,
        threshold = threshold,
        thermosensitive = thermosensitive,
        status = status,
        n_winter_days = length(winter_vals),
        n_summer_days = length(summer_vals),
        stringsAsFactors = FALSE
      )
    }
  )

  do.call(rbind, out)
}
