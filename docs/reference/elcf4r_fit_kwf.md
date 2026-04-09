# Fit a Kernel Wavelet Functional model for daily load curves

Fit a day-ahead Kernel Wavelet Functional (KWF) model on ordered daily
load curves. The implementation computes wavelet-detail distances on the
historical context days, applies Gaussian kernel weights, restricts
those weights to matching calendar groups when available, and can apply
the approximation/detail correction used for mean-level
non-stationarity.

## Usage

``` r
elcf4r_fit_kwf(
  segments,
  covariates = NULL,
  target_covariates = NULL,
  use_temperature = FALSE,
  wavelet = "la12",
  bandwidth = NULL,
  use_mean_correction = TRUE,
  group_col = NULL,
  holidays = NULL,
  weights = NULL,
  recency_decay = NULL,
  temperature_bandwidth = NULL
)
```

## Arguments

- segments:

  Matrix or data frame of past daily load curves (rows are days, columns
  are within-day time points) in chronological order.

- covariates:

  Optional data frame with one row per training segment. When present,
  the function looks for deterministic grouping information in
  `context_group`, `kwf_group`, `calendar_group`, or the column named by
  `group_col`. If no explicit group column is present, groups are
  derived from `date` and `holidays`, or from `dow` as a fallback.

- target_covariates:

  Optional one-row data frame describing the day to forecast. When it
  contains `date`, the previous day is used as the context day for
  calendar grouping, which matches the residential KWF protocol for
  pre-holiday handling.

- use_temperature:

  Deprecated and ignored. Kept for backward compatibility with earlier
  package examples.

- wavelet:

  Wavelet filter name passed to
  [`wavelets::dwt()`](https://rdrr.io/pkg/wavelets/man/dwt.html).
  Defaults to `"la12"`, the least-asymmetric filter. If the series is
  too short for the requested filter, the function falls back to
  `"haar"`.

- bandwidth:

  Optional positive bandwidth for the Gaussian kernel on wavelet
  distances. If `NULL`, it is inferred from the distances to the last
  observed segment.

- use_mean_correction:

  Logical; if `TRUE`, apply the approximation/detail correction used for
  mean-level non-stationarity.

- group_col:

  Optional column name containing precomputed KWF groups in `covariates`
  and `target_covariates`.

- holidays:

  Optional vector of holiday dates used by
  [`elcf4r_calendar_groups()`](https://fbertran.github.io/elcf4R/reference/elcf4r_calendar_groups.md)
  when deterministic groups are derived from `date`.

- weights:

  Optional numeric prior weights of length `nrow(segments)`. Only the
  first `nrow(segments) - 1` values are used in the historical pairing
  step.

- recency_decay:

  Optional non-negative recency coefficient applied as an exponential
  prior on the historical context days.

- temperature_bandwidth:

  Deprecated and ignored. Kept only for backward compatibility with
  older examples.

## Value

An object of class `elcf4r_model` with `method = "kwf"`.

## Examples

``` r
id1 <- subset(
  elcf4r_iflex_example,
  entity_id == unique(elcf4r_iflex_example$entity_id)[1]
)
daily <- elcf4r_build_daily_segments(id1, carry_cols = "participation_phase")
fit <- elcf4r_fit_kwf(
  segments = daily$segments[1:10, ],
  covariates = daily$covariates[1:10, ],
  target_covariates = daily$covariates[11, , drop = FALSE]
)
length(predict(fit))
#> [1] 24
```
