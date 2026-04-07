# Read and normalize the StoreNet household dataset

Read one or more StoreNet-style household CSV files such as `H6_W.csv`,
derive the household identifier from the file name, and return a
normalized long-format panel.

## Usage

``` r
elcf4r_read_storenet(
  path = file.path("data-raw", "H6_W.csv"),
  ids = NULL,
  start = NULL,
  end = NULL,
  tz = "UTC",
  n_max = NULL,
  load_col = "Consumption(W)",
  keep_cols = c("Discharge(W)", "Charge(W)", "Production(W)", "State of Charge(%)")
)
```

## Arguments

- path:

  Path to a StoreNet CSV file or to a directory containing files named
  like `H6_W.csv`.

- ids:

  Optional vector of household identifiers to keep. Identifiers are
  matched against the file stem, for example `"H6_W"`.

- start:

  Optional inclusive lower time bound.

- end:

  Optional inclusive upper time bound.

- tz:

  Time zone used to parse timestamps.

- n_max:

  Optional maximum number of rows to read per file.

- load_col:

  Name of the load column to normalize. Defaults to `"Consumption(W)"`.

- keep_cols:

  Optional extra source columns to keep. Defaults to the main battery
  and production fields when present.

## Value

A normalized data frame with StoreNet household data.
