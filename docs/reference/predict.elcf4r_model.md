# Predict from an `elcf4r_model`

Predict from an `elcf4r_model`

## Usage

``` r
# S3 method for class 'elcf4r_model'
predict(object, newdata = NULL, ...)
```

## Arguments

- object:

  An `elcf4r_model` created by one of the package fit functions.

- newdata:

  Optional new data for methods that need it. For `gam` and `mars`, this
  should be a long-format data frame with the same predictor columns
  used for fitting. For `lstm`, `newdata` may be a matrix or data frame
  of recent daily segments, or a list with elements `segments` and
  optional `covariates`.

- ...:

  Unused, present for method compatibility.

## Value

Numeric predictions. For KWF and LSTM this is a forecast daily curve.
