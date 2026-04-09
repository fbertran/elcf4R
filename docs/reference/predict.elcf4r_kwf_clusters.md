# Assign new segments to a fitted KWF clustering model

Assign new segments to a fitted KWF clustering model

## Usage

``` r
# S3 method for class 'elcf4r_kwf_clusters'
predict(object, segments, ...)
```

## Arguments

- object:

  An `elcf4r_kwf_clusters` object returned by
  [`elcf4r_kwf_cluster_days()`](https://fbertran.github.io/elcf4R/reference/elcf4r_kwf_cluster_days.md).

- segments:

  Matrix or data frame of new daily segments.

- ...:

  Unused, present for method compatibility.

## Value

A character vector of cluster labels.
