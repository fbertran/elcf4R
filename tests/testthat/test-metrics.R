test_that("elcf4r_metrics computes MASE from an explicit naive forecast", {
  truth <- c(10, 12, 14, 16)
  pred <- c(11, 11, 13, 15)
  naive <- c(9, 10, 11, 12)

  out <- elcf4r_metrics(truth, pred, naive_pred = naive)

  mae_model <- mean(abs(truth - pred))
  mae_naive <- mean(abs(truth - naive))
  expect_equal(out$mase, mae_model / mae_naive)
})
