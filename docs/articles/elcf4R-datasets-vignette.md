# Datasets and shipped artifacts

## Overview

`elcf4R` now supports four household-oriented public data sources
through a common normalized panel schema:

- [`elcf4r_read_iflex()`](https://fbertran.github.io/elcf4R/reference/elcf4r_read_iflex.md)
- [`elcf4r_read_storenet()`](https://fbertran.github.io/elcf4R/reference/elcf4r_read_storenet.md)
- [`elcf4r_read_lcl()`](https://fbertran.github.io/elcf4R/reference/elcf4r_read_lcl.md)
- [`elcf4r_read_refit()`](https://fbertran.github.io/elcf4R/reference/elcf4r_read_refit.md)

The package also ships compact example panels and saved benchmark
results so the main vignettes run without external downloads. Raw source
files stay in `data-raw/` and are not redistributed through the package
unless a compact derived artifact has been explicitly built and saved.

Two additional unshipped scaffolds are also available:

- [`elcf4r_download_ideal()`](https://fbertran.github.io/elcf4R/reference/elcf4r_download_ideal.md)
  /
  [`elcf4r_read_ideal()`](https://fbertran.github.io/elcf4R/reference/elcf4r_read_ideal.md)
  for aggregate-electricity hourly summaries from IDEAL.
- [`elcf4r_download_gx()`](https://fbertran.github.io/elcf4R/reference/elcf4r_download_gx.md)
  /
  [`elcf4r_read_gx()`](https://fbertran.github.io/elcf4R/reference/elcf4r_read_gx.md)
  for the GX transformer/community-level dataset.

## Supported dataset matrix

The current dataset surface is:

| Dataset | Reader | Resolution | Temperature in normalized panel | Shipped example | Shipped benchmark |
|:---|:---|:---|:---|:---|:---|
| iFlex | [`elcf4r_read_iflex()`](https://fbertran.github.io/elcf4R/reference/elcf4r_read_iflex.md) | hourly | yes | `elcf4r_iflex_example` | `elcf4r_iflex_benchmark_results` |
| StoreNet (`H6_W`) | [`elcf4r_read_storenet()`](https://fbertran.github.io/elcf4R/reference/elcf4r_read_storenet.md) | 1 minute | optional, source-dependent | `elcf4r_storenet_example` | `elcf4r_storenet_benchmark_results` |
| Low Carbon London | [`elcf4r_read_lcl()`](https://fbertran.github.io/elcf4R/reference/elcf4r_read_lcl.md) | 30 minutes | no | `elcf4r_lcl_example` | `elcf4r_lcl_benchmark_results` |
| REFIT | [`elcf4r_read_refit()`](https://fbertran.github.io/elcf4R/reference/elcf4r_read_refit.md) | user-selected resample | no | `elcf4r_refit_example` | `elcf4r_refit_benchmark_results` |
| ELMAS | not part of the common household reader set | hourly | no | `elcf4r_elmas_toy` | none |

All four household readers return the same core columns:

- `dataset`
- `entity_id`
- `timestamp`
- `date`
- `time_index`
- `y`
- `temp`
- `dow`
- `month`
- `resolution_minutes`

Dataset-specific metadata columns are preserved when available.

## Scaffolded, unshipped datasets

`IDEAL` and `GX` are intentionally documented separately from the core
shipped household matrix.

| Dataset | Helper surface | Level | Current scaffold scope | Shipped example | Shipped benchmark | Licence note |
|:---|:---|:---|:---|:---|:---|:---|
| IDEAL | [`elcf4r_download_ideal()`](https://fbertran.github.io/elcf4R/reference/elcf4r_download_ideal.md), [`elcf4r_read_ideal()`](https://fbertran.github.io/elcf4R/reference/elcf4r_read_ideal.md) | household | aggregate-electricity hourly summaries from `auxiliarydata.zip` | no | no | the current Edinburgh DataShare record states `CC BY 4.0` |
| GX | [`elcf4r_download_gx()`](https://fbertran.github.io/elcf4R/reference/elcf4r_download_gx.md), [`elcf4r_read_gx()`](https://fbertran.github.io/elcf4R/reference/elcf4r_read_gx.md) | transformer/community | SQLite or flat-export normalization to the common panel schema | no | no | treat licence terms as dataset-record specific and recheck before redistribution |

Notes:

- IDEAL support in this release is limited to aggregate electricity and
  does not attempt to parse the raw 1 Hz stream.
- GX is not an individual-household dataset. It is useful as a secondary
  benchmark source for weather and community-level demand behavior, but
  it is not folded into the package’s core household benchmark claims.

## Shipped example panels

The shipped examples are small normalized panels intended for package
examples and vignette code.

``` r
example_sizes <- Filter(
  Negate(is.null),
  list(
    .elcf4r_example_size_row("elcf4r_iflex_example", "iflex"),
    .elcf4r_example_size_row("elcf4r_storenet_example", "storenet"),
    .elcf4r_example_size_row("elcf4r_lcl_example", "lcl"),
    .elcf4r_example_size_row("elcf4r_refit_example", "refit")
  )
)

if (length(example_sizes) == 0L) {
  data.frame()
} else {
  do.call(rbind, example_sizes)
}
#> data frame with 0 columns and 0 rows
```

These objects can be passed directly to:

- [`elcf4r_build_daily_segments()`](https://fbertran.github.io/elcf4R/reference/elcf4r_build_daily_segments.md)
- [`elcf4r_build_benchmark_index()`](https://fbertran.github.io/elcf4R/reference/elcf4r_build_benchmark_index.md)
- [`elcf4r_benchmark()`](https://fbertran.github.io/elcf4R/reference/elcf4r_benchmark.md)

## Shipped benchmark result datasets

Each supported household dataset now has a saved benchmark-result object
built from a fixed local cohort and a deterministic rolling-origin
design.

``` r
benchmark_summary <- Filter(
  Negate(is.null),
  list(
    .elcf4r_benchmark_summary("elcf4r_iflex_benchmark_results", "iflex"),
    .elcf4r_benchmark_summary("elcf4r_storenet_benchmark_results", "storenet"),
    .elcf4r_benchmark_summary("elcf4r_lcl_benchmark_results", "lcl"),
    .elcf4r_benchmark_summary("elcf4r_refit_benchmark_results", "refit")
  )
)

if (length(benchmark_summary) == 0L) {
  data.frame()
} else {
  benchmark_summary <- do.call(rbind, benchmark_summary)
  benchmark_summary[, c("dataset", "method", "nmae", "nrmse", "smape", "mase")]
}
#> data frame with 0 columns and 0 rows
```

These shipped benchmark tables are poster-style artifacts. They are not
intended to replace full local benchmarking on the raw datasets.

## Rebuilding the shipped artifacts

Each shipped dataset is reproducible from a `data-raw/` script:

- `data-raw/elcf4r_iflex_subsets.R`
- `data-raw/elcf4r_iflex_benchmark_results.R`
- `data-raw/elcf4r_storenet_artifacts.R`
- `data-raw/elcf4r_lcl_artifacts.R`
- `data-raw/elcf4r_refit_artifacts.R`

The general pattern is:

1.  Place the original raw files in `data-raw/`.
2.  Read them through `elcf4r_read_*()`.
3.  Build a normalized day index with
    [`elcf4r_build_benchmark_index()`](https://fbertran.github.io/elcf4R/reference/elcf4r_build_benchmark_index.md).
4.  Save a compact example panel.
5.  Run
    [`elcf4r_benchmark()`](https://fbertran.github.io/elcf4R/reference/elcf4r_benchmark.md)
    on a fixed cohort and save the result table.

This keeps the package lightweight while making the shipped examples and
benchmark summaries reproducible.

## Example: daily segments from a shipped panel

``` r
if (exists("elcf4r_iflex_example", inherits = FALSE)) {
  iflex_segments <- elcf4r_build_daily_segments(
    elcf4r_iflex_example,
    carry_cols = c("dataset", "participation_phase", "price_signal")
  )

  dim(iflex_segments$segments)
  head(iflex_segments$covariates[, c("entity_id", "date", "temp_mean", "price_signal")])
} else {
  data.frame()
}
#> data frame with 0 columns and 0 rows
```

## Example: rerun a tiny benchmark locally

``` r
if (exists("elcf4r_lcl_example", inherits = FALSE)) {
  tiny_index <- elcf4r_build_benchmark_index(
    elcf4r_lcl_example,
    carry_cols = "dataset"
  )

  tiny_benchmark <- elcf4r_benchmark(
    panel = elcf4r_lcl_example,
    benchmark_index = tiny_index,
    methods = c("gam", "kwf"),
    cohort_size = 1,
    train_days = 10,
    test_days = 2,
    include_predictions = FALSE
  )

  tiny_benchmark$results[, c("entity_id", "method", "test_date", "nmae", "mase")]
} else {
  data.frame()
}
#> data frame with 0 columns and 0 rows
```
