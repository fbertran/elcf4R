# Read and normalize the IDEAL hourly aggregate-electricity scaffold

Read a direct IDEAL hourly aggregate-electricity file or search an
extracted `auxiliarydata.zip` directory for a matching hourly summary
file, then return a normalized long-format panel.

## Usage

``` r
elcf4r_read_ideal(
  path = "data-raw",
  ids = NULL,
  start = NULL,
  end = NULL,
  tz = "Europe/London",
  n_max = NULL,
  source = "auxiliary_hourly",
  drop_na_load = TRUE
)
```

## Arguments

- path:

  Path to an IDEAL hourly summary file or to an extracted IDEAL
  auxiliary-data directory.

- ids:

  Optional vector of IDEAL household identifiers to keep.

- start:

  Optional inclusive lower time bound.

- end:

  Optional inclusive upper time bound.

- tz:

  Time zone used to parse timestamps. Defaults to `"Europe/London"`.

- n_max:

  Optional maximum number of rows to read.

- source:

  IDEAL source flavor. Currently only `"auxiliary_hourly"` is supported.

- drop_na_load:

  Logical; if `TRUE`, rows with missing load values are dropped.

## Value

A normalized data frame with IDEAL household data.
