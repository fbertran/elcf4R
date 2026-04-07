# Read and normalize the GX residential transformer-level scaffold

Read the GX dataset from either the official SQLite database or a flat
export and return a normalized long-format panel. GX is treated as a
transformer/community-level dataset rather than an individual-household
dataset.

## Usage

``` r
elcf4r_read_gx(
  path = "data-raw",
  ids = NULL,
  start = NULL,
  end = NULL,
  tz = "Asia/Shanghai",
  n_max = NULL,
  drop_na_load = TRUE
)
```

## Arguments

- path:

  Path to a GX SQLite database, a flat export file, or a directory
  containing one of them.

- ids:

  Optional vector of GX community/profile identifiers to keep.

- start:

  Optional inclusive lower time bound.

- end:

  Optional inclusive upper time bound.

- tz:

  Time zone used to parse timestamps. Defaults to `"Asia/Shanghai"`.

- n_max:

  Optional maximum number of rows to read.

- drop_na_load:

  Logical; if `TRUE`, rows with missing load values are dropped.

## Value

A normalized data frame with GX transformer-level data.
