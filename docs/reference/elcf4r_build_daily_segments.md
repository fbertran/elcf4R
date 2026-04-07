# Build daily load-curve segments from a normalized panel

Convert a long-format load table into one row per entity-day and one
column per within-day time index. This is the matrix representation
required by functional load-curve models and rolling benchmark scripts.

## Usage

``` r
elcf4r_build_daily_segments(
  data,
  id_col = "entity_id",
  timestamp_col = "timestamp",
  value_col = "y",
  temp_col = "temp",
  carry_cols = NULL,
  expected_points_per_day = NULL,
  resolution_minutes = NULL,
  complete_days_only = TRUE,
  drop_na_value = TRUE,
  tz = "UTC"
)
```

## Arguments

- data:

  Data frame containing at least entity id, timestamp and load.

- id_col:

  Name of the entity identifier column.

- timestamp_col:

  Name of the timestamp column.

- value_col:

  Name of the load column.

- temp_col:

  Optional name of a temperature column used to derive day summaries.

- carry_cols:

  Optional day-level columns to propagate into the returned covariate
  table. Their first non-missing value within each day is kept.

- expected_points_per_day:

  Expected number of samples per day. If `NULL`, it is derived from
  `resolution_minutes`.

- resolution_minutes:

  Sampling resolution in minutes. If `NULL`, it is inferred from
  timestamps or from a `resolution_minutes` column. Fractional minute
  values are allowed.

- complete_days_only:

  If `TRUE`, incomplete or duplicated days are dropped from the output.

- drop_na_value:

  If `TRUE`, days with missing load values are dropped.

- tz:

  Time zone used to derive dates and within-day positions.

## Value

A list with components `segments`, `covariates`, `resolution_minutes`
and `points_per_day`.

## Examples

``` r
id1 <- subset(
  elcf4r_iflex_example,
  entity_id == unique(elcf4r_iflex_example$entity_id)[1]
)
daily <- elcf4r_build_daily_segments(id1, carry_cols = "participation_phase")
dim(daily$segments)
#> [1] 14 24
names(daily$covariates)
#>  [1] "day_key"             "entity_id"           "date"               
#>  [4] "n_points"            "n_unique_index"      "has_duplicate_index"
#>  [7] "has_missing_value"   "dow"                 "month"              
#> [10] "temp_mean"           "temp_min"            "temp_max"           
#> [13] "participation_phase"
```
