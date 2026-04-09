# Fit an LSTM model for daily load curves

The LSTM implementation uses one or more previous daily curves to
predict the next daily curve. When `use_temperature = TRUE` and
`temp_mean` is available in `covariates`, the daily mean temperature is
added as a second input feature repeated across the within-day time
steps.

## Usage

``` r
elcf4r_fit_lstm(
  segments,
  covariates = NULL,
  use_temperature = FALSE,
  lookback_days = 1L,
  units = 16L,
  epochs = 10L,
  batch_size = 8L,
  validation_split = 0,
  seed = NULL,
  verbose = 0L
)
```

## Arguments

- segments:

  Matrix or data frame of past daily load curves (rows are days, columns
  are time points).

- covariates:

  Optional data frame with one row per training day.

- use_temperature:

  Logical. If `TRUE`, use `temp_mean` from `covariates` as an additional
  input feature when available.

- lookback_days:

  Number of past daily curves used as one training input.

- units:

  Number of hidden units in the LSTM layer.

- epochs:

  Number of training epochs.

- batch_size:

  Batch size used in
  [`keras3::fit()`](https://generics.r-lib.org/reference/fit.html).

- validation_split:

  Validation split passed to
  [`keras3::fit()`](https://generics.r-lib.org/reference/fit.html).

- seed:

  Optional integer seed passed to TensorFlow. When `NULL`, the current
  backend RNG state is used.

- verbose:

  Verbosity level passed to
  [`keras3::fit()`](https://generics.r-lib.org/reference/fit.html) and
  [`predict()`](https://rdrr.io/r/stats/predict.html).

## Value

An object of class `elcf4r_model` with `method = "lstm"`.

## Examples

``` r
if (interactive() &&
    requireNamespace("reticulate", quietly = TRUE) &&
    reticulate::virtualenv_exists("r-tensorflow")) {
  elcf4r_use_tensorflow_env(virtualenv = "r-tensorflow")
  if (isTRUE(getFromNamespace(".elcf4r_lstm_backend_available", "elcf4R")())) {
    id1 <- subset(
      elcf4r_iflex_example,
      entity_id == unique(elcf4r_iflex_example$entity_id)[1]
    )
    daily <- elcf4r_build_daily_segments(id1)
    fit <- elcf4r_fit_lstm(
      segments = daily$segments[1:10, ],
      covariates = daily$covariates[1:10, ],
      use_temperature = TRUE,
      epochs = 1,
      units = 4,
      batch_size = 2,
      verbose = 0
    )
    length(predict(fit))
  }
}
```
