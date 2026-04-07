make_benchmark_panel_fixture <- function() {
  timestamps <- seq(
    as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
    by = "hour",
    length.out = 96L
  )
  time_index <- rep(seq_len(24L), 4L)
  day_index <- rep(0:3, each = 24L)

  raw <- data.frame(
    id = rep(c("home_a", "home_b"), each = length(timestamps)),
    timestamp = rep(timestamps, 2L),
    load = c(
      1 + 0.2 * sin(2 * pi * time_index / 24) + 0.1 * day_index + time_index / 100,
      1.4 + 0.25 * cos(2 * pi * time_index / 24) + 0.08 * day_index + time_index / 120
    ),
    temp = c(
      rep(seq(5, 10, length.out = 24L), 4L),
      rep(seq(2, 7, length.out = 24L), 4L)
    ),
    stringsAsFactors = FALSE
  )

  elcf4r_normalize_panel(
    data = raw,
    id_col = "id",
    timestamp_col = "timestamp",
    load_col = "load",
    temp_col = "temp",
    dataset = "fixture",
    resolution_minutes = 60L,
    tz = "UTC"
  )
}

test_that("elcf4r_build_benchmark_index returns a day-level index", {
  panel <- make_benchmark_panel_fixture()
  index <- elcf4r_build_benchmark_index(panel, carry_cols = "dataset")

  expect_true(all(c(
    "day_key", "entity_id", "date", "dow", "month",
    "temp_mean", "temp_min", "temp_max", "dataset", "n_points"
  ) %in% names(index)))
  expect_equal(nrow(index), 8L)
  expect_equal(index$n_points[[1]], 24L)
  expect_identical(unique(index$dataset), "fixture")
})

test_that("benchmark index slicing supports first and last windows", {
  panel <- make_benchmark_panel_fixture()
  index <- elcf4r_build_benchmark_index(panel, carry_cols = "dataset")

  first_window <- .elcf4r_slice_benchmark_index(
    index,
    required_days = 3L,
    entity_ids = "home_a",
    anchor = "first"
  )
  last_window <- .elcf4r_slice_benchmark_index(
    index,
    required_days = 3L,
    entity_ids = "home_a",
    anchor = "last"
  )

  expect_equal(nrow(first_window), 3L)
  expect_equal(nrow(last_window), 3L)
  expect_equal(first_window$date, sort(first_window$date))
  expect_equal(last_window$date, sort(last_window$date))
  expect_lt(max(first_window$date), max(last_window$date))
})

test_that("elcf4r_benchmark runs built-in methods on a normalized panel", {
  panel <- make_benchmark_panel_fixture()
  index <- elcf4r_build_benchmark_index(panel, carry_cols = "dataset")

  out <- elcf4r_benchmark(
    panel = panel,
    benchmark_index = index,
    methods = c("gam", "mars", "kwf", "kwf_clustered"),
    train_days = 3L,
    test_days = 1L,
    cohort_size = 2L,
    benchmark_name = "fixture_hourly_2_ids_3_train_1_test_4_methods",
    include_predictions = TRUE,
    seed = 17L
  )

  expect_s3_class(out, "elcf4r_benchmark")
  expect_true(all(c("results", "predictions", "cohort_index", "spec", "backend") %in% names(out)))
  expect_equal(nrow(out$results), 8L)
  expect_equal(sort(unique(out$results$method)), c("gam", "kwf", "kwf_clustered", "mars"))
  expect_true(all(out$results$status == "ok"))
  expect_true(all(!is.na(out$results$mase)))
  expect_equal(nrow(out$predictions), 8L * 24L)
  expect_true(all(out$predictions$benchmark_name == "fixture_hourly_2_ids_3_train_1_test_4_methods"))
  expect_true(all(out$predictions$dataset == "fixture"))
  expect_equal(length(out$spec$entity_ids), 2L)
})

test_that("shipped benchmark datasets have populated metrics", {
  shipped <- list(
    iflex = elcf4r_iflex_benchmark_results,
    storenet = elcf4r_storenet_benchmark_results,
    lcl = elcf4r_lcl_benchmark_results,
    refit = elcf4r_refit_benchmark_results
  )

  for (nm in names(shipped)) {
    x <- shipped[[nm]]
    expect_true(all(x$status == "ok"), info = nm)
    expect_true(all(!is.na(x$nmae)), info = nm)
    expect_true(all(!is.na(x$nrmse)), info = nm)
    expect_true(all(!is.na(x$smape)), info = nm)
    expect_true(all(!is.na(x$mase)), info = nm)
  }
})
