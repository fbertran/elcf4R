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

make_storenet_fixture <- function() {
  timestamps <- seq(
    as.POSIXct("2020-01-01 00:00:00", tz = "UTC"),
    by = "min",
    length.out = 1440L
  )

  data.frame(
    date = format(timestamps, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    " Discharge(W)" = rep(0, length(timestamps)),
    " Charge(W)" = rep(5, length(timestamps)),
    " Production(W)" = rep(1, length(timestamps)),
    " Consumption(W)" = seq_len(length(timestamps)) + 100,
    " State of Charge(%)" = rep(50, length(timestamps)),
    H6_W = rep(1, length(timestamps)),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

make_lcl_fixture <- function() {
  timestamps <- seq(
    as.POSIXct("2013-01-01 00:00:00", tz = "UTC"),
    by = "30 min",
    length.out = 48L
  )

  data.frame(
    DateTime = format(timestamps, "%Y-%m-%d %H:%M:%OS", tz = "UTC"),
    MAC000002 = sprintf(" %.3f ", seq_len(48L) / 10),
    MAC000003 = sprintf(" %.3f ", (seq_len(48L) + 100) / 10),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

make_refit_fixture <- function() {
  timestamps <- seq(
    as.POSIXct("2013-10-09 00:00:00", tz = "UTC"),
    by = "30 sec",
    length.out = 2880L
  )
  minute_index <- rep(seq_len(1440L), each = 2L)
  aggregate <- rep(seq_len(1440L), each = 2L) + c(0, 2)
  appliance1 <- rep(seq_len(1440L), each = 2L) / 10 + c(0, 0.4)

  data.frame(
    Time = format(timestamps, "%Y-%m-%d %H:%M:%S", tz = "UTC"),
    Unix = as.integer(as.numeric(timestamps)),
    Aggregate = aggregate,
    Appliance1 = appliance1,
    Issues = rep(0, length(timestamps)),
    check.names = FALSE,
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

test_that("elcf4r_read_storenet returns normalized minute data", {
  tmp_dir <- tempfile("storenet")
  dir.create(tmp_dir)
  tmp_csv <- file.path(tmp_dir, "H6_W.csv")
  utils::write.csv(make_storenet_fixture(), tmp_csv, row.names = FALSE, na = "")

  dat <- elcf4r_read_storenet(
    path = tmp_dir,
    ids = "H6_W",
    start = "2020-01-01 00:00:00",
    end = "2020-01-01 23:59:00"
  )
  seg <- elcf4r_build_daily_segments(
    data = dat,
    carry_cols = c("dataset", "source_file")
  )

  expect_true(all(c(
    "dataset", "entity_id", "timestamp", "date", "time_index", "y",
    "resolution_minutes", "discharge_w", "charge_w", "production_w",
    "state_of_charge_pct", "source_file"
  ) %in% names(dat)))
  expect_identical(unique(dat$dataset), "storenet")
  expect_identical(unique(dat$entity_id), "H6_W")
  expect_equal(nrow(dat), 1440L)
  expect_equal(unique(dat$resolution_minutes), 1)
  expect_equal(dim(seg$segments), c(1L, 1440L))
  expect_equal(seg$segments[1, 1], 101)
  expect_equal(seg$segments[1, 1440], 1540)
})

test_that("elcf4r_read_lcl reshapes wide household data to the common schema", {
  tmp_csv <- tempfile(fileext = ".csv")
  utils::write.table(
    make_lcl_fixture(),
    file = tmp_csv,
    sep = ",",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE
  )

  dat <- elcf4r_read_lcl(path = tmp_csv, ids = "MAC000002")
  seg <- elcf4r_build_daily_segments(data = dat, carry_cols = "dataset")

  expect_true(all(c(
    "dataset", "entity_id", "timestamp", "date", "time_index", "y",
    "resolution_minutes"
  ) %in% names(dat)))
  expect_identical(unique(dat$dataset), "lcl")
  expect_identical(unique(dat$entity_id), "MAC000002")
  expect_equal(nrow(dat), 48L)
  expect_equal(unique(dat$resolution_minutes), 30)
  expect_equal(dim(seg$segments), c(1L, 48L))
  expect_equal(seg$segments[1, 1], 0.1)
  expect_equal(seg$segments[1, 48], 4.8)
})

test_that("elcf4r_read_refit resamples channels onto the common schema", {
  tmp_dir <- tempfile("refit")
  dir.create(tmp_dir)
  tmp_csv <- file.path(tmp_dir, "CLEAN_House1.csv")
  utils::write.csv(make_refit_fixture(), tmp_csv, row.names = FALSE, na = "")

  dat_aggregate <- elcf4r_read_refit(path = tmp_dir)
  dat_multi <- elcf4r_read_refit(
    path = tmp_dir,
    channels = c("Aggregate", "Appliance1")
  )
  seg <- elcf4r_build_daily_segments(
    data = dat_aggregate,
    carry_cols = c("dataset", "house_id", "channel")
  )

  expect_true(all(c(
    "dataset", "entity_id", "timestamp", "date", "time_index", "y",
    "resolution_minutes", "house_id", "channel", "unix", "issues"
  ) %in% names(dat_aggregate)))
  expect_identical(unique(dat_aggregate$dataset), "refit")
  expect_identical(unique(dat_aggregate$entity_id), "CLEAN_House1")
  expect_identical(unique(dat_aggregate$house_id), "CLEAN_House1")
  expect_identical(unique(dat_aggregate$channel), "Aggregate")
  expect_equal(nrow(dat_aggregate), 1440L)
  expect_equal(unique(dat_aggregate$resolution_minutes), 1)
  expect_equal(dim(seg$segments), c(1L, 1440L))
  expect_equal(seg$segments[1, 1], 2)
  expect_true(all(c("CLEAN_House1::Aggregate", "CLEAN_House1::Appliance1") %in% unique(dat_multi$entity_id)))
})
