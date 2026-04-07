# Fit a clustered KWF model for daily load curves

Cluster dyadically resampled daily curves in a wavelet-energy feature
space and use the resulting cluster labels as the grouping structure
inside the KWF forecast.

## Usage

``` r
elcf4r_fit_kwf_clustered(
  segments,
  covariates = NULL,
  target_covariates = NULL,
  wavelet = "la12",
  bandwidth = NULL,
  use_mean_correction = TRUE,
  max_clusters = 10L,
  nstart = 30L,
  cluster_seed = NULL,
  weights = NULL,
  recency_decay = NULL,
  clustering = NULL
)
```

## Arguments

- segments:

  Matrix or data frame of past daily load curves in chronological order.

- covariates:

  Optional data frame with one row per segment.

- target_covariates:

  Optional one-row data frame for the target day.

- wavelet:

  Wavelet filter name passed to
  [`wavelets::dwt()`](https://rdrr.io/pkg/wavelets/man/dwt.html).
  Defaults to `"la12"`.

- bandwidth:

  Optional positive bandwidth for the Gaussian kernel in the underlying
  KWF fit.

- use_mean_correction:

  Logical; if `TRUE`, apply the approximation/detail correction in the
  underlying KWF fit.

- max_clusters:

  Maximum number of candidate clusters considered by the Sugar jump
  heuristic.

- nstart:

  Number of random starts for `kmeans`.

- cluster_seed:

  Deprecated and ignored. Clustered KWF now uses deterministic
  non-random starts.

- weights:

  Optional prior weights passed through to the base KWF fit.

- recency_decay:

  Optional recency prior passed through to the base KWF fit.

- clustering:

  Optional `elcf4r_kwf_clusters` object. When supplied, the stored
  clustering model is reused instead of being refit.

## Value

An object of class `elcf4r_model` with `method = "kwf_clustered"`.
