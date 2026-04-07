# Normalize a load panel to the elcf4R schema

Convert a raw long-format load table into a normalized panel that uses
the column names expected by the package examples and model wrappers.

## Usage

``` r
elcf4r_normalize_panel(
  data,
  id_col,
  timestamp_col,
  load_col,
  temp_col = NULL,
  dataset = NA_character_,
  resolution_minutes = NULL,
  tz = "UTC",
  keep_cols = NULL
)
```

## Arguments

- data:

  Data frame containing at least an entity identifier, a time stamp and
  a load column.

- id_col:

  Name of the entity identifier column.

- timestamp_col:

  Name of the timestamp column.

- load_col:

  Name of the load column.

- temp_col:

  Optional name of the temperature column.

- dataset:

  Short dataset label stored in the normalized output.

- resolution_minutes:

  Sampling resolution in minutes. If `NULL`, it is inferred from the
  timestamps. Fractional minute values are allowed for high-frequency
  data.

- tz:

  Time zone used to parse timestamps.

- keep_cols:

  Optional character vector of extra source columns to keep.

## Value

A data frame with normalized columns `dataset`, `entity_id`,
`timestamp`, `date`, `time_index`, `y`, `temp`, `dow`, `month` and
`resolution_minutes`, plus any requested `keep_cols`.
