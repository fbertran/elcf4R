<!-- README.md is generated from README.Rmd. Please edit that file -->


# eclf4R: Forecasting Individual Electricity Load Curves <img src="man/figures/eclf4R_hex.svg" align="right" width="200"/>

## Frédéric Bertrand, Fatima Fahs and Myriam Maumy

<!-- badges: start -->
[![R-CMD-check](https://github.com/fbertran/eclf4R/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/fbertran/eclf4R/actions/workflows/R-CMD-check.yaml)
[![R-hub](https://github.com/fbertran/eclf4R/actions/workflows/rhub.yaml/badge.svg)](https://github.com/fbertran/eclf4R/actions/workflows/rhub.yaml)
<!-- badges: end -->

Implements Kernel Wavelet Functional (KWF),
    clustered KWF, Generalized Additive Models (GAM), Multivariate
    Adaptive Regression Splines (MARS) and RNN LSTM models to
    forecast individual electricity load curves, following the
    methodology described in Fahs (2023) and related articles and
    posters. Includes normalized dataset adapters for iFlex,
    StoreNet, Low Carbon London and REFIT, compact shipped example
    panels, and saved benchmark artifacts.
    
This site was created by F. Bertrand and the examples reproduced on it were created by F. Bertrand, F. Fahs and M. Maumy.

## Installation

You can install the latest version of the eclf4R package from [github](https://github.com) with:


``` r
devtools::install_github("fbertran/eclf4R")
```

## Current Scope

The exported forecasting methods currently covered by the package are:

- `elcf4r_fit_gam()`
- `elcf4r_fit_mars()`
- `elcf4r_fit_kwf()`
- `elcf4r_fit_kwf_clustered()`
- `elcf4r_fit_lstm()`

The current dataset adapters and shipped benchmark artifacts cover:

- iFlex
- StoreNet (`H6_W`)
- Low Carbon London
- REFIT

The current download helpers are:

- `elcf4r_download_elmas()`
- `elcf4r_download_storenet()`

Additional datasets under review:

- `IDEAL`: candidate future adapter/helper. The current source record
  indicates `CC BY 4.0`, so the previous non-commercial wording should
  not be reused.
- `GX`: candidate secondary benchmark dataset. It is transformer-level
  rather than individual-household data, and its licence should be
  re-verified at the dataset-record level before any shipped subset is
  considered.

## Shipped example and benchmark datasets

The package now ships compact example panels and saved benchmark results for
iFlex, StoreNet, Low Carbon London and REFIT, so the main documentation can
run without external downloads. These artifacts are derived from local raw
files through the reproducible scripts in `data-raw/`.

The current shipped benchmark artifacts are:

- iFlex: `15` households, `28` train days, `7` test days
- StoreNet: `1` household (`H6_W`), `5` train days, `2` test days
- Low Carbon London: `1` thermosensitive household, `56` train days,
  `7` test days
- REFIT: `2` thermosensitive households, `56` train days, `7` test days

### Vignettes

There are more insights and examples in the vignettes.


``` r
vignette("elcf4R-iflex-workflow", package = "eclf4R")
vignette("elcf4R-datasets-vignette", package = "eclf4R")
```

## Quick Benchmark Summary

The shipped benchmark artifacts now cover iFlex, StoreNet, Low Carbon London
and REFIT. The same workflow is available programmatically through
`elcf4r_build_benchmark_index()` and `elcf4r_benchmark()`.


``` r
do.call(
  rbind,
  list(
    transform(
      aggregate(
        cbind(nmae, nrmse, smape, mase) ~ method,
        data = elcf4r_iflex_benchmark_results,
        FUN = function(x) round(mean(x, na.rm = TRUE), 4)
      ),
      dataset = "iflex"
    ),
    transform(
      aggregate(
        cbind(nmae, nrmse, smape, mase) ~ method,
        data = elcf4r_storenet_benchmark_results,
        FUN = function(x) round(mean(x, na.rm = TRUE), 4)
      ),
      dataset = "storenet"
    ),
    transform(
      aggregate(
        cbind(nmae, nrmse, smape, mase) ~ method,
        data = elcf4r_lcl_benchmark_results,
        FUN = function(x) round(mean(x, na.rm = TRUE), 4)
      ),
      dataset = "lcl"
    ),
    transform(
      aggregate(
        cbind(nmae, nrmse, smape, mase) ~ method,
        data = elcf4r_refit_benchmark_results,
        FUN = function(x) round(mean(x, na.rm = TRUE), 4)
      ),
      dataset = "refit"
    )
  )
)
#>           method   nmae  nrmse  smape   mase  dataset
#> 1            gam 0.2435 0.3121 0.3222 0.8782    iflex
#> 2            kwf 0.2740 0.3479 0.3477 0.9756    iflex
#> 3  kwf_clustered 0.2688 0.3501 0.3292 0.9247    iflex
#> 4           lstm 0.2270 0.2891 0.3181 0.8534    iflex
#> 5           mars 0.2319 0.2946 0.3092 0.8310    iflex
#> 6            gam 0.0942 0.1406 0.8018 0.8088 storenet
#> 7            kwf 0.1927 0.2440 1.4786 1.6952 storenet
#> 8           lstm 0.0960 0.1562 0.8105 0.7845 storenet
#> 9           mars 0.0928 0.1381 0.7989 0.7897 storenet
#> 10           gam 0.1732 0.2471 0.9649 1.7856      lcl
#> 11           kwf 0.1758 0.2386 1.1692 1.8105      lcl
#> 12 kwf_clustered 0.1410 0.2034 0.8509 1.1719      lcl
#> 13          lstm 0.2079 0.2711 1.0954 2.2924      lcl
#> 14          mars 0.1689 0.2343 1.0337 1.6638      lcl
#> 15           gam 0.1766 0.2609 0.6033 1.2210    refit
#> 16           kwf 0.1946 0.2366 0.5965 1.3543    refit
#> 17 kwf_clustered 0.1959 0.2462 0.5878 1.3097    refit
#> 18          lstm 0.1633 0.2385 0.5621 1.1697    refit
#> 19          mars 0.1652 0.2313 0.5394 1.1501    refit
```
