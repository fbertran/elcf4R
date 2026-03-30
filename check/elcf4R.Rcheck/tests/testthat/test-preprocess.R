make_iflex_fixture <- function() {
  timestamps <- seq(
    as.POSIXct("2020-02-01 00:00:00", tz = "UTC"),
    by = "hour",
    length.out = 48L
  )

  data.frame(
    ID = rep(c("Exp_1", "Exp_2"), each = length(timestamps)),
    From = format(rep(timestamps, 2L), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    Participation_Phase = rep(c("Phase_1", "Phase_2"), each = length(timestamps)),
    Demand_kWh = c(seq_len(length(timestamps)), seq_len(length(timestamps)) + 100) / 10,
    Price_signal = c(
      "",
      rep("A_10", 23L),
      rep("B_2", 24L),
      rep("C_15", 48L)
    ),
    Experiment_price_NOK_kWh = c(rep(1.0, 24L), rep(2.0, 24L), rep(3.0, 48L)),
    Temperature = rep(seq(1, 48), 2L),
    Temperature24 = rep(seq(0, 47), 2L),
    Temperature48 = rep(seq(-1, 46), 2L),
    Temperature72 = rep(seq(-2, 45), 2L),
    stringsAsFactors = FALSE
  )
}

test_that("elcf4r_read_iflex returns normalized hourly data", {
  tmp_csv <- tempfile(fileext = ".csv")
  utils::write.csv(make_iflex_fixture(), tmp_csv, row.names = FALSE, na = "")

  dat_full <- elcf4r_read_iflex(path = tmp_csv, ids = "Exp_1")
  dat <- elcf4r_read_iflex(
    path = tmp_csv,
    ids = "Exp_1",
    start = "2020-02-01 12:00:00",
    end = "2020-02-02 11:00:00"
  )

  expect_true(all(c(
    "dataset", "entity_id", "timestamp", "date", "time_index", "y", "temp",
    "dow", "month", "participation_phase", "price_signal", "price_nok_kwh",
    "temp24", "temp48", "temp72", "resolution_minutes"
  ) %in% names(dat)))
  expect_identical(unique(dat$dataset), "iflex")
  expect_identical(unique(dat$entity_id), "Exp_1")
  expect_equal(nrow(dat), 24L)
  expect_equal(min(dat$timestamp), as.POSIXct("2020-02-01 12:00:00", tz = "UTC"))
  expect_equal(max(dat$timestamp), as.POSIXct("2020-02-02 11:00:00", tz = "UTC"))
  expect_equal(unique(dat$resolution_minutes), 60L)
  expect_equal(dat$time_index[1], 13L)
  expect_true(is.na(dat_full$price_signal[1]))
})

test_that("elcf4r_build_daily_segments drops incomplete days and returns matrices", {
  tmp_csv <- tempfile(fileext = ".csv")
  fixture <- make_iflex_fixture()
  fixture <- fixture[fixture$ID == "Exp_1", ]
  fixture <- fixture[-48L, ]
  utils::write.csv(fixture, tmp_csv, row.names = FALSE, na = "")

  dat <- elcf4r_read_iflex(path = tmp_csv)
  seg <- elcf4r_build_daily_segments(
    data = dat,
    carry_cols = c("dataset", "participation_phase", "price_signal")
  )

  expect_true(is.matrix(seg$segments))
  expect_equal(dim(seg$segments), c(1L, 24L))
  expect_equal(seg$points_per_day, 24L)
  expect_equal(seg$resolution_minutes, 60L)
  expect_equal(rownames(seg$segments), "Exp_1__2020-02-01")
  expect_equal(seg$covariates$dataset[[1]], "iflex")
  expect_equal(seg$covariates$participation_phase[[1]], "Phase_1")
  expect_equal(seg$covariates$price_signal[[1]], "A_10")
  expect_equal(seg$covariates$temp_mean[[1]], mean(seq_len(24L)))
  expect_equal(seg$segments[1, 1], 0.1)
  expect_equal(seg$segments[1, 24], 2.4)
})
