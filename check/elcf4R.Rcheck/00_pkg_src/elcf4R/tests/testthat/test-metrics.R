test_that("metrics behave as expected on simple series", {
  y  <- 1:10
  y2 <- y
  m  <- elcf4r_metrics(y, y2, seasonal_period = 2)
  expect_equal(m$nmae, 0)
  expect_equal(m$nrmse, 0)
  expect_equal(m$smape, 0)
  expect_lt(m$mase, 1e-8)
})

test_that("GAM fits and predicts", {
  skip_if_not_installed("mgcv")
  set.seed(123)
  n <- 200
  dat <- data.frame(
    y = sin(seq_len(n) / 10) + rnorm(n, sd = 0.1),
    time_index = rep(seq_len(48), length.out = n),
    dow = factor(rep(1:7, length.out = n)),
    month = factor(rep(1:12, length.out = n)),
    temp = 15 + rnorm(n)
  )
  fit <- elcf4r_fit_gam(dat, use_temperature = TRUE)
  expect_s3_class(fit, "elcf4r_model")
})