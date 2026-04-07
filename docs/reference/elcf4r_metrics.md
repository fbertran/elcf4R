# Forecast accuracy metrics for load curves

Compute NMAE, NRMSE, sMAPE and MASE between observed and predicted load
curves, as in the posters.

## Usage

``` r
elcf4r_metrics(truth, pred, seasonal_period = NULL, naive_pred = NULL)
```

## Arguments

- truth:

  Numeric vector or matrix of observed values.

- pred:

  Numeric vector or matrix of predicted values, same shape.

- seasonal_period:

  Seasonal period for the naive benchmark in the MASE denominator (for
  daily curves with half hourly sampling, a value of 48 is appropriate).

- naive_pred:

  Optional numeric vector or matrix of naive benchmark predictions with
  the same shape as `truth`. When supplied, MASE is computed against
  this explicit naive forecast instead of inferring the denominator from
  `seasonal_period` within `truth`.

## Value

A named list with elements `nmae`, `nrmse`, `smape`, `mase`.
