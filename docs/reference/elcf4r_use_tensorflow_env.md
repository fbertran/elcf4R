# Select the Python environment used for TensorFlow-backed LSTM fits

This helper provides an explicit, user-invoked way to bind the Python
environment used by `reticulate` before calling
[`elcf4r_fit_lstm()`](https://fbertran.github.io/elcf4R/reference/elcf4r_fit_lstm.md).

## Usage

``` r
elcf4r_use_tensorflow_env(python = NULL, virtualenv = NULL, required = TRUE)
```

## Arguments

- python:

  Optional path to a Python interpreter passed to
  [`reticulate::use_python()`](https://rstudio.github.io/reticulate/reference/use_python.html).

- virtualenv:

  Optional virtualenv name or path passed to
  [`reticulate::use_virtualenv()`](https://rstudio.github.io/reticulate/reference/use_python.html).

- required:

  Logical passed to the corresponding `reticulate` selector.

## Value

Invisibly returns the selected Python interpreter path when it can be
determined.

## Examples

``` r
if (interactive() &&
    requireNamespace("reticulate", quietly = TRUE) &&
    reticulate::virtualenv_exists("r-tensorflow")) {
  elcf4r_use_tensorflow_env(virtualenv = "r-tensorflow")
}
```
