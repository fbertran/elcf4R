# Classify thermosensitivity from daily load data

Estimate thermosensitivity using the residential rule based on the ratio
between mean winter load and mean summer load.

## Usage

``` r
elcf4r_classify_thermosensitivity(
  data,
  id_col = "entity_id",
  date_col = "date",
  value_col = "y",
  threshold = 1.5,
  winter_months = c(12L, 1L, 2L),
  summer_months = c(6L, 7L, 8L)
)
```

## Arguments

- data:

  Data frame containing at least an identifier, a date and a load
  column. Long-format panels are accepted and are aggregated to mean
  daily load before classification.

- id_col:

  Name of the entity identifier column.

- date_col:

  Name of the date column.

- value_col:

  Name of the load column.

- threshold:

  Ratio threshold above which the series is classified as
  thermosensitive. Defaults to `1.5`.

- winter_months:

  Integer vector of winter months.

- summer_months:

  Integer vector of summer months.

## Value

A data frame with one row per entity and columns `winter_mean`,
`summer_mean`, `ratio`, `thermosensitive`, and `status`.

## Examples

``` r
example_ts <- data.frame(
  entity_id = rep("home_1", 4),
  date = as.Date(c("2024-01-10", "2024-01-11", "2024-07-10", "2024-07-11")),
  y = c(12, 11, 6, 5)
)
elcf4r_classify_thermosensitivity(example_ts)
#>   entity_id winter_mean summer_mean    ratio threshold thermosensitive status
#> 1    home_1        11.5         5.5 2.090909       1.5            TRUE     ok
#>   n_winter_days n_summer_days
#> 1             2             2
```
