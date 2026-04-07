# eclf4R, Sobol Indices for Models with Fixed and Stochastic Parameters ![](reference/figures/eclf4R_hex.svg)

## Frédéric Bertrand, Fatima Fahs and Myriam Maumy

Implements Kernel Wavelet Functional (KWF), Generalized Additive Models
(GAM), Multivariate Adaptive Regression Splines (MARS) and RNN LSTM
models to forecast individual electricity load curves, following the
methodology described in Fahs (2023) and related articles and posters.
Includes small demo datasets and helper functions to download large
public datasets such as ELMAS, StoreNet Ireland and IDEAL.

This site was created by F. Bertrand and the examples reproduced on it
were created by F. Bertrand, F. Fahs and M. Maumy.

## Installation

You can install the latest version of the eclf4R package from
[github](https://github.com) with:

``` r
devtools::install_github("fbertran/eclf4R")
```

## Two complementary analysis paths

The package now ships a compact iFlex example panel and saved benchmark
results, so the documentation can run without external downloads.

### Vignettes

There are more insights and examples in the vignettes.

``` r
vignette("elcf4R-iflex-workflow", package = "eclf4R")
vignette("elcf4R-datasets-vignette", package = "eclf4R")
```

## Quick Benchmark Summary

The shipped iFlex benchmark now includes `gam`, `mars`, `kwf` and `lstm`
results on the same fixed rolling-origin design.

``` r
aggregate(
  cbind(nmae, nrmse, smape, fit_seconds) ~ method,
  data = elcf4r_iflex_benchmark_results,
  FUN = function(x) round(mean(x, na.rm = TRUE), 4)
)
#>   method   nmae  nrmse  smape fit_seconds
#> 1    gam 0.2435 0.3121 0.3222      0.0269
#> 2    kwf 0.2224 0.2861 0.2946      0.0007
#> 3   lstm 0.2296 0.2919 0.3188      1.1992
#> 4   mars 0.2319 0.2946 0.3092      0.0145
```
