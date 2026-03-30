#' Fit a MARS model for load curves
#'
#' @inheritParams elcf4r_fit_gam
#' @return An `elcf4r_model` object with `method = "mars"`.
#' @export
#' @examples
#' id1 <- subset(
#'   elcf4r_iflex_example,
#'   entity_id == unique(elcf4r_iflex_example$entity_id)[1]
#' )
#' train_data <- subset(id1, date < sort(unique(id1$date))[11])
#' test_data <- subset(id1, date == sort(unique(id1$date))[11])
#' fit <- elcf4r_fit_mars(train_data[, c("y", "time_index", "dow", "month", "temp")], TRUE)
#' pred <- predict(fit, newdata = test_data[, c("y", "time_index", "dow", "month", "temp")])
#' length(pred)
elcf4r_fit_mars <- function(data, use_temperature = FALSE) {
  stopifnot(all(c("y", "time_index") %in% names(data)))
  
  x_vars <- c("time_index", "dow", "month")
  if (use_temperature) x_vars <- c(x_vars, "temp")
  
  x <- as.data.frame(data[x_vars])
  y <- data[["y"]]
  
  fit <- earth::earth(x = x, y = y)
  
  structure(
    list(model = fit, method = "mars", use_temperature = use_temperature,
         x_vars = x_vars),
    class = "elcf4r_model"
  )
}
