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
#> 0.2215960 0.2522648 0.2061798 1.0477434
```

``` r
"LSTM example skipped because a working Keras/TensorFlow backend is not available in this R environment."
```

## Inspect shipped benchmark results

The package also ships precomputed benchmark results on a fixed iFlex
cohort. In the current build these results cover `gam`, `mars`, `kwf`,
`kwf_clustered` and `lstm`.

``` r
head(elcf4r_iflex_benchmark_results)
#>                                  benchmark_name dataset entity_id        method
#> 1 iflex_hourly_10_ids_28_train_5_test_5_methods   iflex     Exp_1           gam
#> 2 iflex_hourly_10_ids_28_train_5_test_5_methods   iflex     Exp_1          mars
#> 3 iflex_hourly_10_ids_28_train_5_test_5_methods   iflex     Exp_1           kwf
#> 4 iflex_hourly_10_ids_28_train_5_test_5_methods   iflex     Exp_1 kwf_clustered
#> 5 iflex_hourly_10_ids_28_train_5_test_5_methods   iflex     Exp_1          lstm
#> 6 iflex_hourly_10_ids_28_train_5_test_5_methods   iflex     Exp_1           gam
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
#> 1       0.057     ok          <NA> 0.2241390 0.3029546 0.11050062 0.7570273
#> 2       0.037     ok          <NA> 0.2986949 0.3565707 0.15316209 1.0088391
#> 3       0.065     ok          <NA> 0.2622522 0.3346779 0.13014701 0.8857544
#> 4       0.142     ok          <NA> 0.2039969 0.2643067 0.09952173 0.6889975
#> 5       1.203     ok          <NA> 0.3218673 0.4079799 0.16103600 1.0871037
#> 6       0.031     ok          <NA> 0.1502679 0.2054841 0.12878440 0.8595982

aggregate(
  cbind(nmae, nrmse, smape, mase, fit_seconds) ~ method,
  data = elcf4r_iflex_benchmark_results,
  FUN = function(x) round(mean(x, na.rm = TRUE), 4)
)
#>          method   nmae  nrmse  smape   mase fit_seconds
#> 1           gam 0.2435 0.3121 0.3222 0.8782      0.0250
#> 2           kwf 0.2740 0.3479 0.3477 0.9756      0.0379
#> 3 kwf_clustered 0.2640 0.3388 0.3295 0.9115      0.0904
#> 4          lstm 0.2296 0.2919 0.3188 0.8538      1.1791
#> 5          mars 0.2319 0.2946 0.3092 0.8310      0.0142
```

This object is intended to support reproducible package examples and to
provide a stable reference point for future benchmark extensions.
