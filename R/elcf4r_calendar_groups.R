#' Derive deterministic KWF calendar groups
#'
#' Build the deterministic day groups used by the residential KWF workflow:
#' weekdays, `pre_holiday`, and `holiday`.
#'
#' @param dates Vector coercible to `Date`.
#' @param holidays Optional vector of holiday dates. If supplied, holiday dates
#'   are labelled `"holiday"` and the dates immediately before them are labelled
#'   `"pre_holiday"`.
#'
#' @return An ordered factor with levels `monday`, `tuesday`, `wednesday`,
#'   `thursday`, `friday`, `saturday`, `sunday`, `pre_holiday`, `holiday`.
#' @export
#'
#' @examples
#' elcf4r_calendar_groups(
#'   as.Date(c("2024-12-24", "2024-12-25", "2024-12-26")),
#'   holidays = as.Date("2024-12-25")
#' )
elcf4r_calendar_groups <- function(dates, holidays = NULL) {
  dates <- as.Date(dates)
  if (anyNA(dates)) {
    stop("`dates` must be coercible to `Date` without missing values.")
  }

  holidays <- unique(stats::na.omit(as.Date(holidays)))
  weekday_levels <- c(
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday",
    "pre_holiday",
    "holiday"
  )

  weekday_map <- c(
    sunday = "sunday",
    monday = "monday",
    tuesday = "tuesday",
    wednesday = "wednesday",
    thursday = "thursday",
    friday = "friday",
    saturday = "saturday"
  )
  weekday_names <- weekday_map[
    names(weekday_map)[as.POSIXlt(dates, tz = "UTC")$wday + 1L]
  ]

  out <- unname(weekday_names)
  is_holiday <- dates %in% holidays
  is_pre_holiday <- !is_holiday & ((dates + 1L) %in% holidays)

  out[is_pre_holiday] <- "pre_holiday"
  out[is_holiday] <- "holiday"

  factor(out, levels = weekday_levels, ordered = TRUE)
}
