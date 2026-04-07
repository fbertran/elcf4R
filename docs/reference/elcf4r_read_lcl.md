# Read and normalize the Low Carbon London dataset

Read a wide Low Carbon London (LCL) smart-meter file and reshape it into
a normalized long-format panel with one row per household timestamp.

## Usage

``` r
elcf4r_read_lcl(
  path = file.path("data-raw", "LCL_2013.csv"),
  ids = NULL,
  start = NULL,
  end = NULL,
  tz = "UTC",
  n_max = NULL,
  drop_na_load = TRUE
)
```

## Arguments

- path:

  Path to an LCL CSV file or to a directory containing one.

- ids:

  Optional vector of LCL household identifiers to keep, for example
  `"MAC000002"`.

- start:

  Optional inclusive lower time bound.

- end:

  Optional inclusive upper time bound.

- tz:

  Time zone used to parse timestamps.

- n_max:

  Optional maximum number of timestamp rows to read.

- drop_na_load:

  Logical; if `TRUE`, rows with missing load values are dropped after
  reshaping.

## Value

A normalized data frame with LCL household data.
