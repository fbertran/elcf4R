# Build a day-level benchmark index from a normalized panel

Create a compact day-level index from a normalized panel. The returned
object contains one row per complete entity-day and can be reused to
define deterministic benchmark cohorts without shipping the full panel.

## Usage

``` r
elcf4r_build_benchmark_index(
  data,
  carry_cols = NULL,
  id_col = "entity_id",
  timestamp_col = "timestamp",
  value_col = "y",
  temp_col = "temp",
  resolution_minutes = NULL,
  complete_days_only = TRUE,
  drop_na_value = TRUE,
  tz = "UTC"
)
```

## Arguments

- data:

  Normalized panel data, typically returned by one of the
  `elcf4r_read_*()` adapters.

- carry_cols:

  Optional character vector of additional day-level columns to propagate
  into the benchmark index. If `NULL`, all non-core columns are carried.

- id_col:

  Name of the entity identifier column.

- timestamp_col:

  Name of the timestamp column.

- value_col:

  Name of the load column.

- temp_col:

  Name of the temperature column.

- resolution_minutes:

  Sampling resolution in minutes. If `NULL`, it is inferred from the
  data.

- complete_days_only:

  Passed to
  [`elcf4r_build_daily_segments()`](https://fbertran.github.io/elcf4R/reference/elcf4r_build_daily_segments.md).

- drop_na_value:

  Passed to
  [`elcf4r_build_daily_segments()`](https://fbertran.github.io/elcf4R/reference/elcf4r_build_daily_segments.md).

- tz:

  Time zone used to derive dates and within-day positions.

## Value

A day-level data frame suitable for
[`elcf4r_benchmark()`](https://fbertran.github.io/elcf4R/reference/elcf4r_benchmark.md).

## Examples

``` r
idx <- elcf4r_build_benchmark_index(
  elcf4r_iflex_example,
  carry_cols = c("dataset", "participation_phase", "price_signal")
)
head(idx)
#>             day_key entity_id       date       dow month temp_mean temp_min
#> 1 Exp_1__2020-01-06     Exp_1 2020-01-06    Monday    01  7.508333      6.4
#> 2 Exp_1__2020-01-07     Exp_1 2020-01-07   Tuesday    01  7.254167      5.8
#> 3 Exp_1__2020-01-08     Exp_1 2020-01-08 Wednesday    01  6.312500      4.2
#> 4 Exp_1__2020-01-09     Exp_1 2020-01-09  Thursday    01  3.420833      0.6
#> 5 Exp_1__2020-01-10     Exp_1 2020-01-10    Friday    01  1.445833     -0.4
#> 6 Exp_1__2020-01-11     Exp_1 2020-01-11  Saturday    01  6.754167      4.4
#>   temp_max dataset participation_phase price_signal n_points
#> 1      8.7   iflex             Phase_1         <NA>       24
#> 2      9.7   iflex             Phase_1         <NA>       24
#> 3     10.3   iflex             Phase_1         <NA>       24
#> 4      5.5   iflex             Phase_1         <NA>       24
#> 5      4.7   iflex             Phase_1         <NA>       24
#> 6      8.8   iflex             Phase_1         <NA>       24
```
