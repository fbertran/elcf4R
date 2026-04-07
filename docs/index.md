# eclf4R: Forecasting Individual Electricity Load Curves ![](reference/figures/eclf4R_hex.svg)

## Frédéric Bertrand, Fatima Fahs and Myriam Maumy

Implements Kernel Wavelet Functional (KWF), clustered KWF, Generalized
Additive Models (GAM), Multivariate Adaptive Regression Splines (MARS)
and RNN LSTM models to forecast individual electricity load curves,
following the methodology described in Fahs (2023) and related articles
and posters. Includes normalized dataset adapters for iFlex, StoreNet,
Low Carbon London and REFIT, scaffolded download/read support for IDEAL
and GX, compact shipped example panels, and saved benchmark artifacts.

This site was created by F. Bertrand and the examples reproduced on it
were created by F. Bertrand, F. Fahs and M. Maumy.

## Installation

You can install the latest version of the eclf4R package from
[github](https://github.com) with:

``` r
devtools::install_github("fbertran/eclf4R")
```

## Current Scope

The exported forecasting methods currently covered by the package are:

- [`elcf4r_fit_gam()`](https://fbertran.github.io/eclf4R/reference/elcf4r_fit_gam.md)
- [`elcf4r_fit_mars()`](https://fbertran.github.io/eclf4R/reference/elcf4r_fit_mars.md)
- [`elcf4r_fit_kwf()`](https://fbertran.github.io/eclf4R/reference/elcf4r_fit_kwf.md)
- [`elcf4r_fit_kwf_clustered()`](https://fbertran.github.io/eclf4R/reference/elcf4r_fit_kwf_clustered.md)
- [`elcf4r_fit_lstm()`](https://fbertran.github.io/eclf4R/reference/elcf4r_fit_lstm.md)

The current dataset adapters and shipped benchmark artifacts cover:

- iFlex
- StoreNet (`H6_W`)
- Low Carbon London
- REFIT

The current download helpers are:

- [`elcf4r_download_elmas()`](https://fbertran.github.io/eclf4R/reference/elcf4r_download_elmas.md)
- [`elcf4r_download_storenet()`](https://fbertran.github.io/eclf4R/reference/elcf4r_download_storenet.md)
- [`elcf4r_download_ideal()`](https://fbertran.github.io/eclf4R/reference/elcf4r_download_ideal.md)
- [`elcf4r_download_gx()`](https://fbertran.github.io/eclf4R/reference/elcf4r_download_gx.md)

Scaffolded, unshipped dataset adapters:

- `IDEAL`:
  [`elcf4r_download_ideal()`](https://fbertran.github.io/eclf4R/reference/elcf4r_download_ideal.md)
  and
  [`elcf4r_read_ideal()`](https://fbertran.github.io/eclf4R/reference/elcf4r_read_ideal.md)
  provide a first-pass aggregate-electricity scaffold built around the
  hourly summaries in `auxiliarydata.zip`. The current Edinburgh
  DataShare record states `CC BY 4.0`. No IDEAL-derived package dataset
  is shipped in this release.
- `GX`:
  [`elcf4r_download_gx()`](https://fbertran.github.io/eclf4R/reference/elcf4r_download_gx.md)
  and
  [`elcf4r_read_gx()`](https://fbertran.github.io/eclf4R/reference/elcf4r_read_gx.md)
  provide a secondary transformer/community-level scaffold from the
  official figshare dataset record. GX is not treated as part of the
  package’s core individual-household benchmark set, and no GX-derived
  package dataset is shipped in this release. Licence terms should be
  rechecked against the official dataset record before any
  redistribution.

The current unshipped scaffold readers are:

- [`elcf4r_read_ideal()`](https://fbertran.github.io/eclf4R/reference/elcf4r_read_ideal.md)
- [`elcf4r_read_gx()`](https://fbertran.github.io/eclf4R/reference/elcf4r_read_gx.md)

## Shipped example and benchmark datasets

The package now ships compact example panels and saved benchmark results
for iFlex, StoreNet, Low Carbon London and REFIT, so the main
documentation can run without external downloads. These artifacts are
derived from local raw files through the reproducible scripts in
`data-raw/`.

The current shipped benchmark artifacts are:

- iFlex: `15` households, `28` train days, `7` test days
- StoreNet: `1` household (`H6_W`), `5` train days, `2` test days
- Low Carbon London: `1` thermosensitive household, `56` train days, `7`
  test days
- REFIT: `2` thermosensitive households, `56` train days, `7` test days

### Vignettes

There are more insights and examples in the vignettes.

``` r
vignette("elcf4R-iflex-workflow", package = "eclf4R")
vignette("elcf4R-datasets-vignette", package = "eclf4R")
```

## Quick Benchmark Summary

The shipped benchmark artifacts now cover iFlex, StoreNet, Low Carbon
London and REFIT. The same workflow is available programmatically
through
[`elcf4r_build_benchmark_index()`](https://fbertran.github.io/eclf4R/reference/elcf4r_build_benchmark_index.md)
and
[`elcf4r_benchmark()`](https://fbertran.github.io/eclf4R/reference/elcf4r_benchmark.md).

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
  do.call(rbind, benchmark_summary)
}
#> data frame with 0 columns and 0 rows
```
