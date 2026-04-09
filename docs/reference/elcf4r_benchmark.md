# Run a rolling-origin benchmark on a normalized panel

Evaluate the package forecasting methods on a normalized panel using a
deterministic rolling-origin design. The runner supports the current
temperature-aware `gam`, `mars`, `kwf`, `kwf_clustered` and `lstm`
wrappers and returns both aggregate scores and, optionally, saved point
forecasts.

## Usage

``` r
elcf4r_benchmark(
  panel,
  benchmark_index = NULL,
  methods = NULL,
  entity_ids = NULL,
  cohort_size = NULL,
  train_days = 28L,
  test_days = 5L,
  benchmark_name = NULL,
  dataset = NULL,
  use_temperature = TRUE,
  method_args = NULL,
  include_predictions = TRUE,
  thermosensitivity_panel = NULL,
  benchmark_index_carry_cols = NULL,
  seed = NULL,
  tz = "UTC"
)
```

## Arguments

- panel:

  Normalized panel data, typically returned by one of the
  `elcf4r_read_*()` adapters.

- benchmark_index:

  Optional day-level index. If `NULL`, it is created with
  [`elcf4r_build_benchmark_index()`](https://fbertran.github.io/elcf4R/reference/elcf4r_build_benchmark_index.md).

- methods:

  Character vector of method names to evaluate. Supported values are
  `"gam"`, `"mars"`, `"kwf"`, `"kwf_clustered"` and `"lstm"`. If `NULL`,
  the runner uses `gam`, `mars`, `kwf`, `kwf_clustered` and adds `lstm`
  only when its backend is available.

- entity_ids:

  Optional character vector of entity IDs to benchmark.

- cohort_size:

  Optional maximum number of eligible entities to keep after sorting by
  `entity_id`.

- train_days:

  Number of days in each training window.

- test_days:

  Number of one-day rolling test origins per entity.

- benchmark_name:

  Optional benchmark identifier. If `NULL`, one is derived from the
  dataset label and benchmark design.

- dataset:

  Optional dataset label overriding `unique(panel$dataset)`.

- use_temperature:

  Logical; if `TRUE`, methods that support temperature will use it when
  non-missing temperature information is available for the current
  window.

- method_args:

  Optional named list of per-method argument overrides.

- include_predictions:

  Logical; if `TRUE`, return a long table of saved point forecasts and
  naive forecasts.

- thermosensitivity_panel:

  Optional normalized panel used for thermosensitivity classification.
  Defaults to `panel`.

- benchmark_index_carry_cols:

  Optional `carry_cols` passed to
  [`elcf4r_build_benchmark_index()`](https://fbertran.github.io/elcf4R/reference/elcf4r_build_benchmark_index.md)
  when `benchmark_index` is not supplied.

- seed:

  Optional integer seed forwarded to methods that support user-supplied
  seeding, such as LSTM, unless overridden in `method_args`.

- tz:

  Time zone used to derive dates and within-day positions.

## Value

An object of class `elcf4r_benchmark` with elements `results`,
`predictions`, `cohort_index`, `spec` and `backend`.

## Examples

``` r
id1 <- subset(
  elcf4r_iflex_example,
  entity_id == unique(elcf4r_iflex_example$entity_id)[1]
)
keep_dates <- sort(unique(id1$date))[1:6]
panel_small <- subset(id1, date %in% keep_dates)
bench <- elcf4r_benchmark(
  panel = panel_small,
  methods = "gam",
  cohort_size = 1,
  train_days = 4,
  test_days = 1,
  include_predictions = TRUE
)
head(bench$results)
#>                                benchmark_name dataset entity_id method
#> 1 iflex_hourly_1_ids_4_train_1_test_1_methods   iflex     Exp_1    gam
#>    test_date train_start  train_end train_days test_points use_temperature
#> 1 2020-01-10  2020-01-06 2020-01-09          4          24            TRUE
#>   thermosensitive     thermosensitivity_status thermosensitivity_ratio
#> 1              NA insufficient_summer_coverage                      NA
#>   fit_seconds status error_message      nmae     nrmse     smape     mase
#> 1       0.053     ok          <NA> 0.3498549 0.4230886 0.2092393 1.154271
```
