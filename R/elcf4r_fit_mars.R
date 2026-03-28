#' Fit a MARS model for load curves
#'
#' @inheritParams elcf4r_fit_gam
#' @return An `elcf4r_model` object with `method = "mars"`.
#' @export
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
