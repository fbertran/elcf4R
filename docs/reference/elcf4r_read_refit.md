# Read and normalize the REFIT cleaned household dataset

Read one or more `CLEAN_House*.csv` files from the REFIT dataset,
optionally select appliance channels, resample them to a regular time
grid, and return a normalized long-format panel.

## Usage

``` r
elcf4r_read_refit(
  path = "data-raw",
  house_ids = NULL,
  channels = "Aggregate",
  start = NULL,
  end = NULL,
  tz = "UTC",
  resolution_minutes = 1L,
  agg_fun = c("mean", "sum", "last"),
  n_max = NULL,
  drop_na_load = TRUE
)
```

## Arguments

- path:

  Path to a REFIT file or to a directory containing `CLEAN_House*.csv`
  files.

- house_ids:

  Optional vector of house identifiers to keep. These are matched
  against file stems such as `"CLEAN_House1"`.

- channels:

  Character vector of load channels to extract. Defaults to
  `"Aggregate"`.

- start:

  Optional inclusive lower time bound.

- end:

  Optional inclusive upper time bound.

- tz:

  Time zone used to parse timestamps.

- resolution_minutes:

  Target regular resolution in minutes for the normalized output.
  Defaults to `1`.

- agg_fun:

  Aggregation used when resampling to the target grid. One of `"mean"`,
  `"sum"` or `"last"`.

- n_max:

  Optional maximum number of raw rows to read per file.

- drop_na_load:

  Logical; if `TRUE`, rows with missing load values are dropped after
  resampling.

## Value

A normalized data frame with REFIT household data.
