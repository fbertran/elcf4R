test_that("elcf4r_calendar_groups labels weekdays, pre-holidays and holidays", {
  groups <- elcf4r_calendar_groups(
    as.Date(c("2024-12-24", "2024-12-25", "2024-12-26")),
    holidays = as.Date("2024-12-25")
  )

  expect_equal(as.character(groups), c("pre_holiday", "holiday", "thursday"))
})

test_that("elcf4r_classify_thermosensitivity uses the winter-summer ratio rule", {
  dat <- data.frame(
    entity_id = rep(c("home_a", "home_b"), each = 4),
    date = as.Date(c(
      "2024-01-10", "2024-01-11", "2024-07-10", "2024-07-11",
      "2024-01-10", "2024-01-11", "2024-02-10", "2024-02-11"
    )),
    y = c(12, 11, 6, 5, 8, 8, 7, 7)
  )

  out <- elcf4r_classify_thermosensitivity(dat)
  out <- out[order(out$entity_id), ]

  expect_true(isTRUE(out$thermosensitive[[1]]))
  expect_equal(out$status[[1]], "ok")
  expect_true(is.na(out$thermosensitive[[2]]))
  expect_equal(out$status[[2]], "insufficient_summer_coverage")
})

test_that("elcf4r_fit_kwf returns a KWF model with context weights", {
  set.seed(123)
  seg <- matrix(rnorm(5 * 16), nrow = 5, ncol = 16)
  covariates <- data.frame(
    date = as.Date("2024-01-01") + 0:4,
    dow = c("monday", "tuesday", "wednesday", "thursday", "friday")
  )
  target_covariates <- data.frame(date = as.Date("2024-01-06"))

  fit <- elcf4r_fit_kwf(
    segments = seg,
    covariates = covariates,
    target_covariates = target_covariates
  )

  expect_s3_class(fit, "elcf4r_model")
  expect_equal(fit$method, "kwf")
  expect_equal(fit$n_segments, 5L)
  expect_equal(fit$n_time, 16L)
  expect_length(fit$fitted_curve, 16L)
  expect_length(fit$weights, 5L)
  expect_equal(fit$weights[[5]], 0)
  expect_equal(sum(fit$context_weights), 1, tolerance = 1e-8)
})

test_that("KWF wavelet distance ignores pure level shifts", {
  base <- sin(seq(0, 2 * pi, length.out = 16))
  shifted <- base + 5

  base_decomp <- .elcf4r_kwf_decompose_segment(
    segment = base,
    wavelet = "haar",
    n_levels = 4L
  )
  shifted_decomp <- .elcf4r_kwf_decompose_segment(
    segment = shifted,
    wavelet = "haar",
    n_levels = 4L
  )

  expect_lt(
    .elcf4r_kwf_distance(base_decomp$detail_coeffs, shifted_decomp$detail_coeffs),
    1e-8
  )
})

test_that("KWF mean correction improves a simple mean-shift forecast", {
  base_curve <- c(1, 2, 3, 4, 4, 3, 2, 1, 1, 2, 3, 4, 4, 3, 2, 1)
  segments <- do.call(
    rbind,
    lapply(0:3, function(k) base_curve + k)
  )
  target <- base_curve + 4

  fit_plain <- elcf4r_fit_kwf(
    segments = segments,
    wavelet = "haar",
    use_mean_correction = FALSE
  )
  fit_corrected <- elcf4r_fit_kwf(
    segments = segments,
    wavelet = "haar",
    use_mean_correction = TRUE
  )

  err_plain <- mean(abs(predict(fit_plain) - target))
  err_corrected <- mean(abs(predict(fit_corrected) - target))

  expect_lt(err_corrected, err_plain)
})

test_that("KWF zeroes weights outside the matching calendar group", {
  seg <- rbind(
    rep(1, 16),
    rep(2, 16),
    rep(3, 16),
    rep(4, 16)
  )
  covariates <- data.frame(
    calendar_group = c("weekday", "weekend", "weekday", "weekday")
  )
  fit <- elcf4r_fit_kwf(
    segments = seg,
    covariates = covariates,
    wavelet = "haar"
  )

  expect_gt(fit$weights[[1]], 0)
  expect_equal(fit$weights[[2]], 0)
  expect_gt(fit$weights[[3]], 0)
})

test_that("elcf4r_fit_kwf_clustered returns clustered KWF metadata", {
  base_a <- c(rep(0, 8), rep(2, 8))
  base_b <- rep(c(0, 2), 8)
  seg <- rbind(
    base_a,
    base_b,
    base_a + 0.1,
    base_b + 0.1,
    base_a + 0.2
  )

  fit <- elcf4r_fit_kwf_clustered(
    segments = seg,
    wavelet = "haar",
    max_clusters = 4L,
    nstart = 20L
  )

  expect_s3_class(fit, "elcf4r_model")
  expect_equal(fit$method, "kwf_clustered")
  expect_length(fit$cluster_assignments, nrow(seg))
  expect_gte(fit$cluster_k, 1L)
  if (fit$cluster_k > 1L) {
    off_cluster <- fit$cluster_assignments[1:(nrow(seg) - 1L)] != fit$target_group
    expect_true(all(fit$context_weights[off_cluster] == 0))
  }
})

test_that("elcf4r_kwf_cluster_days returns reusable deterministic assignments", {
  base_a <- c(rep(0, 8), rep(2, 8))
  base_b <- rep(c(0, 2), 8)
  seg <- rbind(
    base_a,
    base_b,
    base_a + 0.1,
    base_b + 0.1,
    base_a + 0.2,
    base_b + 0.2
  )

  clustering_1 <- elcf4r_kwf_cluster_days(
    segments = seg,
    wavelet = "haar",
    max_clusters = 4L,
    nstart = 20L,
    cluster_seed = 17L
  )
  clustering_2 <- elcf4r_kwf_cluster_days(
    segments = seg,
    wavelet = "haar",
    max_clusters = 4L,
    nstart = 20L,
    cluster_seed = 17L
  )

  expect_s3_class(clustering_1, "elcf4r_kwf_clusters")
  expect_equal(clustering_1$cluster_labels, clustering_2$cluster_labels)
  expect_equal(clustering_1$cluster_centers, clustering_2$cluster_centers)
  expect_equal(
    elcf4r_assign_kwf_clusters(clustering_1, seg),
    clustering_1$cluster_labels
  )
  expect_equal(
    elcf4r_assign_kwf_clusters(
      clustering_1,
      rbind(base_a + 0.15, base_b + 0.15)
    ),
    clustering_1$cluster_labels[c(1L, 2L)]
  )
})

test_that("elcf4r_fit_kwf_clustered reuses a supplied clustering model", {
  base_a <- c(rep(0, 8), rep(2, 8))
  base_b <- rep(c(0, 2), 8)
  seg <- rbind(
    base_a,
    base_b,
    base_a + 0.1,
    base_b + 0.1,
    base_a + 0.2,
    base_b + 0.2
  )
  clustering <- elcf4r_kwf_cluster_days(
    segments = seg,
    wavelet = "haar",
    max_clusters = 4L,
    nstart = 20L,
    cluster_seed = 17L
  )

  fit <- elcf4r_fit_kwf_clustered(
    segments = seg,
    wavelet = "haar",
    clustering = clustering,
    cluster_seed = 999L
  )

  expect_identical(fit$cluster_assignments, clustering$cluster_labels)
  expect_identical(fit$cluster_target_group, tail(clustering$cluster_labels, 1L))
  expect_identical(fit$clustering$cluster_labels, clustering$cluster_labels)
})

test_that("predict.elcf4r_model works for kwf objects", {
  set.seed(1)
  seg <- matrix(rnorm(4 * 24), nrow = 4, ncol = 24)
  fit <- elcf4r_fit_kwf(segments = seg)
  pred <- predict(fit)
  expect_equal(length(pred), 24L)
})

test_that("predict.elcf4r_model works for clustered kwf objects", {
  seg <- rbind(
    c(rep(0, 8), rep(1, 8)),
    rep(c(0, 1), 8),
    c(rep(0, 8), rep(1, 8)),
    c(rep(0, 8), rep(1, 8))
  )
  fit <- elcf4r_fit_kwf_clustered(segments = seg, wavelet = "haar")
  pred <- predict(fit)
  expect_equal(length(pred), 16L)
})

test_that("elcf4r_fit_lstm returns a model when keras3 is available", {
  skip_if_not_installed("reticulate")
  skip_if_not_installed("keras3")
  skip_if_not_installed("tensorflow")
  skip_if_not(reticulate::virtualenv_exists("r-tensorflow"))
  elcf4r_use_tensorflow_env(virtualenv = "r-tensorflow", required = TRUE)
  skip_if_not(.elcf4r_lstm_backend_available())

  set.seed(1)
  seg <- matrix(rnorm(8 * 6), nrow = 8, ncol = 6)
  covariates <- data.frame(temp_mean = seq_len(8))

  fit <- elcf4r_fit_lstm(
    segments = seg,
    covariates = covariates,
    use_temperature = TRUE,
    units = 4L,
    epochs = 1L,
    batch_size = 2L,
    verbose = 0L
  )

  expect_s3_class(fit, "elcf4r_model")
  expect_equal(fit$method, "lstm")
  expect_equal(length(predict(fit)), 6L)
})
