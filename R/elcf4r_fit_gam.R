#' Fit a GAM model for load curves
#'
#' @param data Data frame with columns `y` (load), `time_index`
#'   (numeric or factor for within day position), `dow`, `month`,
#'   optional `temp` and other covariates.
#' @param use_temperature Logical. If `TRUE`, include temperature
#'   as smooth effect and interactions.
#'
#' @return An object of class `elcf4r_model` with `method = "gam"`.
#' @export
#' @examples
#' id1 <- subset(
#'   elcf4r_iflex_example,
#'   entity_id == unique(elcf4r_iflex_example$entity_id)[1]
#' )
#' train_data <- subset(id1, date < sort(unique(id1$date))[11])
#' test_data <- subset(id1, date == sort(unique(id1$date))[11])
#' fit <- elcf4r_fit_gam(train_data[, c("y", "time_index", "dow", "month", "temp")], TRUE)
#' pred <- predict(fit, newdata = test_data[, c("y", "time_index", "dow", "month", "temp")])
#' length(pred)
elcf4r_fit_gam <- function(data, use_temperature = FALSE) {
  stopifnot(all(c("y", "time_index") %in% names(data)))
  if (use_temperature && !"temp" %in% names(data)) {
    stop("Temperature is not available in `data`.")
  }
  data <- .elcf4r_prepare_calendar_predictors(data)
  
  if (use_temperature) {
    form <- y ~
      s(time_index, bs = "cc") +
      s(dow, bs = "re") +
      s(temp) +
      ti(time_index, temp)
  } else {
    form <- y ~
      s(time_index, bs = "cc") +
      s(dow, bs = "re")
  }
  
  fit <- mgcv::gam(form, data = data, drop.unused.levels = FALSE)
  structure(
    list(model = fit, method = "gam", use_temperature = use_temperature),
    class = "elcf4r_model"
  )
}

.elcf4r_prepare_calendar_predictors <- function(data) {
  data <- as.data.frame(data, stringsAsFactors = FALSE)

  if ("dow" %in% names(data)) {
    dow_levels <- c(
      "Sunday", "Monday", "Tuesday", "Wednesday",
      "Thursday", "Friday", "Saturday"
    )
    data[["dow"]] <- factor(as.character(data[["dow"]]), levels = dow_levels)
  }
  if ("month" %in% names(data)) {
    month_levels <- sprintf("%02d", seq_len(12L))
    data[["month"]] <- factor(as.character(data[["month"]]), levels = month_levels)
  }

  data
}
