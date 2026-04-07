# iFlex Workflow with Shipped Example Data

## Overview

This vignette shows a complete lightweight workflow using only datasets
that ship with the package:

- `elcf4r_iflex_example` for preprocessing and model fitting examples.
- `elcf4r_iflex_benchmark_results` for inspecting saved benchmark
  results.

## Inspect the shipped iFlex example

``` r
dim(elcf4r_iflex_example)
#> [1] 1008   16
length(unique(elcf4r_iflex_example$entity_id))
#> [1] 3
range(elcf4r_iflex_example$timestamp)
#> [1] "2020-01-06 00:00:00 UTC" "2020-01-19 23:00:00 UTC"
head(elcf4r_iflex_example[, c("entity_id", "timestamp", "y", "temp")])
#>   entity_id           timestamp     y temp
#> 1     Exp_1 2020-01-06 00:00:00 2.043  7.6
#> 2     Exp_1 2020-01-06 01:00:00 2.358  7.5
#> 3     Exp_1 2020-01-06 02:00:00 2.496  7.5
#> 4     Exp_1 2020-01-06 03:00:00 2.076  7.5
#> 5     Exp_1 2020-01-06 04:00:00 2.065  7.5
#> 6     Exp_1 2020-01-06 05:00:00 2.059  7.5
```

## Build daily segments

We work on one participant to keep the example compact.

``` r
id1 <- subset(
  elcf4r_iflex_example,
  entity_id == unique(elcf4r_iflex_example$entity_id)[1]
)

daily <- elcf4r_build_daily_segments(
  id1,
  carry_cols = c("participation_phase", "price_signal")
)

dim(daily$segments)
#> [1] 14 24
head(daily$covariates[, c("date", "dow", "temp_mean", "participation_phase")])
#>                         date       dow temp_mean participation_phase
#> Exp_1__2020-01-06 2020-01-06    Monday  7.508333             Phase_1
#> Exp_1__2020-01-07 2020-01-07   Tuesday  7.254167             Phase_1
#> Exp_1__2020-01-08 2020-01-08 Wednesday  6.312500             Phase_1
#> Exp_1__2020-01-09 2020-01-09  Thursday  3.420833             Phase_1
#> Exp_1__2020-01-10 2020-01-10    Friday  1.445833             Phase_1
#> Exp_1__2020-01-11 2020-01-11  Saturday  6.754167             Phase_1
```

## Fit forecasting models on the example panel

We train on the first 10 days and predict the 11th day.

``` r
train_days <- daily$covariates$date[1:10]
test_day <- daily$covariates$date[11]

train_long <- subset(id1, date %in% train_days)
test_long <- subset(id1, date == test_day)

fit_gam <- elcf4r_fit_gam(
  train_long[, c("y", "time_index", "dow", "month", "temp")],
  use_temperature = TRUE
)
pred_gam <- predict(
  fit_gam,
  newdata = test_long[, c("y", "time_index", "dow", "month", "temp")]
)

fit_mars <- elcf4r_fit_mars(
  train_long[, c("y", "time_index", "dow", "month", "temp")],
  use_temperature = TRUE
)
pred_mars <- predict(
  fit_mars,
  newdata = test_long[, c("y", "time_index", "dow", "month", "temp")]
)

fit_kwf <- elcf4r_fit_kwf(
  segments = daily$segments[1:10, ],
  covariates = daily$covariates[1:10, , drop = FALSE],
  target_covariates = daily$covariates[11, , drop = FALSE]
)
pred_kwf <- predict(fit_kwf)

fit_kwf_clustered <- elcf4r_fit_kwf_clustered(
  segments = daily$segments[1:10, ],
  covariates = daily$covariates[1:10, , drop = FALSE],
  target_covariates = daily$covariates[11, , drop = FALSE]
)
pred_kwf_clustered <- predict(fit_kwf_clustered)

naive_day <- as.numeric(daily$segments[10, ])

rbind(
  gam = unlist(elcf4r_metrics(test_long$y, pred_gam, naive_pred = naive_day)),
  mars = unlist(elcf4r_metrics(test_long$y, pred_mars, naive_pred = naive_day)),
  kwf = unlist(elcf4r_metrics(test_long$y, pred_kwf, naive_pred = naive_day)),
  kwf_clustered = unlist(elcf4r_metrics(test_long$y, pred_kwf_clustered, naive_pred = naive_day))
)
#>                    nmae     nrmse     smape      mase
#> gam           0.1961463 0.2355394 0.1796715 0.9274129
#> mars          0.1690549 0.1920249 0.1600477 0.7993201
#> kwf           0.1404839 0.1821267 0.1394477 0.6642319
#> kwf_clustered 0.1640983 0.1907997 0.1529166 0.7758848
```

An LSTM example is available when the `keras3` and `tensorflow` packages
are installed and configured:

``` r
fit_lstm <- elcf4r_fit_lstm(
  segments = daily$segments[1:10, ],
  covariates = daily$covariates[1:10, , drop = FALSE],
  use_temperature = TRUE,
  epochs = 1,
  units = 4,
  batch_size = 2,
  verbose = 0
)

pred_lstm <- predict(fit_lstm)
unlist(elcf4r_metrics(test_long$y, pred_lstm, naive_pred = naive_day))
#>      nmae     nrmse     smape      mase 
#> 0.2246107 0.2551583 0.2088074 1.0619975
```

``` r
"LSTM example skipped because a working Keras/TensorFlow backend is not available in this R environment."
```

## Run a small rolling benchmark

The package also exposes a reusable rolling-origin benchmark runner that
works on normalized panels produced by the `elcf4r_read_*()` adapters.

``` r
benchmark_index <- elcf4r_build_benchmark_index(
  elcf4r_iflex_example,
  carry_cols = c("dataset", "participation_phase", "price_signal")
)

benchmark_small <- elcf4r_benchmark(
  panel = elcf4r_iflex_example,
  benchmark_index = benchmark_index,
  methods = c("gam", "kwf"),
  cohort_size = 1,
  train_days = 10,
  test_days = 2,
  include_predictions = FALSE
)

benchmark_small$results
#>                                 benchmark_name dataset entity_id method
#> 1 iflex_hourly_1_ids_10_train_2_test_2_methods   iflex     Exp_1    gam
#> 2 iflex_hourly_1_ids_10_train_2_test_2_methods   iflex     Exp_1    kwf
#> 3 iflex_hourly_1_ids_10_train_2_test_2_methods   iflex     Exp_1    gam
#> 4 iflex_hourly_1_ids_10_train_2_test_2_methods   iflex     Exp_1    kwf
#>    test_date train_start  train_end train_days test_points use_temperature
#> 1 2020-01-16  2020-01-06 2020-01-15         10          24            TRUE
#> 2 2020-01-16  2020-01-06 2020-01-15         10          24            TRUE
#> 3 2020-01-17  2020-01-07 2020-01-16         10          24            TRUE
#> 4 2020-01-17  2020-01-07 2020-01-16         10          24            TRUE
#>   thermosensitive     thermosensitivity_status thermosensitivity_ratio
#> 1              NA insufficient_summer_coverage                      NA
#> 2              NA insufficient_summer_coverage                      NA
#> 3              NA insufficient_summer_coverage                      NA
#> 4              NA insufficient_summer_coverage                      NA
#>   fit_seconds status error_message      nmae     nrmse     smape      mase
#> 1       0.018     ok          <NA> 0.1961463 0.2355394 0.1796715 0.9274129
#> 2       0.012     ok          <NA> 0.1404839 0.1821267 0.1394477 0.6642319
#> 3       0.019     ok          <NA> 0.3692809 0.4462295 0.1641611 1.3876600
#> 4       0.012     ok          <NA> 0.5393512 0.6402973 0.2242763 2.0267394
```

## Inspect shipped benchmark results

The package also ships precomputed benchmark results on a fixed iFlex
cohort. In the current build these results cover `gam`, `mars`, `kwf`,
`kwf_clustered` and `lstm`.

``` r
head(elcf4r_iflex_benchmark_results)
#>                                  benchmark_name dataset entity_id        method
#> 1 iflex_hourly_15_ids_28_train_7_test_5_methods   iflex     Exp_1           gam
#> 2 iflex_hourly_15_ids_28_train_7_test_5_methods   iflex     Exp_1          mars
#> 3 iflex_hourly_15_ids_28_train_7_test_5_methods   iflex     Exp_1           kwf
#> 4 iflex_hourly_15_ids_28_train_7_test_5_methods   iflex     Exp_1 kwf_clustered
#> 5 iflex_hourly_15_ids_28_train_7_test_5_methods   iflex     Exp_1          lstm
#> 6 iflex_hourly_15_ids_28_train_7_test_5_methods   iflex     Exp_1           gam
#>    test_date train_start  train_end train_days test_points use_temperature
#> 1 2020-02-03  2020-01-06 2020-02-02         28          24            TRUE
#> 2 2020-02-03  2020-01-06 2020-02-02         28          24            TRUE
#> 3 2020-02-03  2020-01-06 2020-02-02         28          24            TRUE
#> 4 2020-02-03  2020-01-06 2020-02-02         28          24            TRUE
#> 5 2020-02-03  2020-01-06 2020-02-02         28          24            TRUE
#> 6 2020-02-04  2020-01-07 2020-02-03         28          24            TRUE
#>   thermosensitive     thermosensitivity_status thermosensitivity_ratio
#> 1              NA insufficient_summer_coverage                      NA
#> 2              NA insufficient_summer_coverage                      NA
#> 3              NA insufficient_summer_coverage                      NA
#> 4              NA insufficient_summer_coverage                      NA
#> 5              NA insufficient_summer_coverage                      NA
#> 6              NA insufficient_summer_coverage                      NA
#>   fit_seconds status error_message      nmae     nrmse      smape      mase
#> 1       0.073     ok          <NA> 0.2241390 0.3029546 0.11050062 0.7570273
#> 2       0.062     ok          <NA> 0.2986949 0.3565707 0.15316209 1.0088391
#> 3       0.067     ok          <NA> 0.2622522 0.3346779 0.13014701 0.8857544
#> 4       0.184     ok          <NA> 0.2039969 0.2643067 0.09952173 0.6889975
#> 5       1.229     ok          <NA> 0.3100784 0.3850647 0.15454029 1.0472868
#> 6       0.024     ok          <NA> 0.1502679 0.2054841 0.12878440 0.8595982

aggregate(
  cbind(nmae, nrmse, smape, mase, fit_seconds) ~ method,
  data = elcf4r_iflex_benchmark_results,
  FUN = function(x) round(mean(x, na.rm = TRUE), 4)
)
#>          method   nmae  nrmse  smape   mase fit_seconds
#> 1           gam 0.2275 0.2908 0.3116 0.8519      0.0238
#> 2           kwf 0.2469 0.3125 0.3303 0.9083      0.0344
#> 3 kwf_clustered 0.2561 0.3289 0.3351 0.9335      0.1276
#> 4          lstm 0.2365 0.2967 0.3373 0.9129      1.2425
#> 5          mars 0.2209 0.2808 0.3031 0.8220      0.0132
```

This object is intended to support reproducible package examples and to
provide a stable reference point for future benchmark extensions.
