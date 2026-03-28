# tests/testthat/test-kwf.R

test_that("elcf4r_fit_kwf returns an object with expected structure", {
  set.seed(123)
  seg <- matrix(rnorm(5 * 4), nrow = 5, ncol = 4)
  w <- c(1, 2, 3, 4, 5)

  fit <- elcf4r_fit_kwf(segments = seg, weights = w)

  expect_s3_class(fit, "elcf4r_model")
  expect_equal(fit$method, "kwf")
  expect_equal(fit$n_segments, 5L)
  expect_equal(fit$n_time, 4L)
  expect_length(fit$fitted_curve, 4L)
})

test_that("predict.elcf4r_model works for kwf objects", {
  set.seed(1)
  seg <- matrix(rnorm(3 * 10), nrow = 3, ncol = 10)
  fit <- elcf4r_fit_kwf(segments = seg)
  pred <- predict(fit)
  expect_equal(length(pred), 10L)
})
