# iFlex benchmark results for shipped forecasting methods

Saved benchmark results for a deterministic rolling-origin evaluation on
a subset of the iFlex data. The shipped results use a fixed participant
cohort, a 28-day training window and multiple one-day rolling test
forecasts per participant. The current shipped benchmark includes the
operational `gam`, `mars`, `kwf`, `kwf_clustered` and `lstm` wrappers.

## Format

A data frame with 20 variables:

- benchmark_name:

  Identifier of the benchmark design.

- dataset:

  Dataset label, always `"iflex"`.

- entity_id:

  Participant identifier.

- method:

  Forecasting method: `gam`, `mars`, `kwf`, `kwf_clustered` or `lstm`.

- test_date:

  Date of the forecast target day.

- train_start:

  First day in the training window.

- train_end:

  Last day in the training window.

- train_days:

  Number of training days.

- test_points:

  Number of hourly points in the target day.

- use_temperature:

  Logical flag for temperature-aware fitting.

- thermosensitive:

  Thermosensitivity flag when seasonal coverage is sufficient, otherwise
  `NA`.

- thermosensitivity_status:

  Status of the winter/summer ratio classification step.

- thermosensitivity_ratio:

  Estimated winter/summer mean-load ratio when available.

- fit_seconds:

  Elapsed fit-and-predict time in seconds.

- status:

  Benchmark execution status.

- error_message:

  Error message when a fit failed.

- nmae:

  Normalized mean absolute error.

- nrmse:

  Normalized root mean squared error.

- smape:

  Symmetric mean absolute percentage error.

- mase:

  Mean absolute scaled error.

## Source

Derived from `elcf4r_iflex_benchmark_index` and the public iFlex raw
file with `data-raw/elcf4r_iflex_benchmark_results.R`.
