# Read and normalize the iFlex hourly dataset

Read the iFlex hourly consumption table and return a normalized
long-format panel ready for feature engineering, segmentation and
benchmarking.

## Usage

``` r
elcf4r_read_iflex(
  path = file.path("data-raw", "iFlex"),
  ids = NULL,
  start = NULL,
  end = NULL,
  tz = "UTC",
  n_max = NULL
)
```

## Arguments

- path:

  Path to `data_hourly.csv` or to the directory that contains it.

- ids:

  Optional vector of participant identifiers to keep.

- start:

  Optional inclusive lower time bound.

- end:

  Optional inclusive upper time bound.

- tz:

  Time zone used to parse timestamps. Defaults to `"UTC"` because the
  iFlex timestamps are stored with a trailing `Z`.

- n_max:

  Optional maximum number of rows to read. Intended for quick
  prototyping on a small subset of the raw file.

## Value

A normalized data frame with load, temperature and calendar fields. The
output also keeps `participation_phase`, `price_signal`,
`price_nok_kwh`, `temp24`, `temp48` and `temp72`.
