# Cluster daily segments for clustered KWF

Build a reusable clustering model for daily load-curve segments in the
wavelet-energy feature space used by the clustered KWF workflow.

## Usage

``` r
elcf4r_kwf_cluster_days(
  segments,
  wavelet = "la12",
  max_clusters = 10L,
  nstart = 30L,
  cluster_seed = NULL
)
```

## Arguments

- segments:

  Matrix or data frame of daily load curves in chronological order.

- wavelet:

  Wavelet filter name passed to
  [`wavelets::dwt()`](https://rdrr.io/pkg/wavelets/man/dwt.html).
  Defaults to `"la12"`.

- max_clusters:

  Maximum number of candidate clusters considered by the Sugar jump
  heuristic.

- nstart:

  Number of random starts for `kmeans`.

- cluster_seed:

  Deprecated and ignored. Clustering now uses deterministic non-random
  starts.

## Value

An object of class `elcf4r_kwf_clusters`.
