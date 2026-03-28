// src/kwf_core.cpp
//
// Simple C plus plus skeleton for a Kernel plus Wavelet plus Functional
// model core. The current implementation only computes a simple
// weighted average curve. It is intended as a placeholder that can
// later be replaced by a full KWF implementation.
//
// This file uses Rcpp to expose the C plus plus routine to R.
//
// To activate it in the package:
//   - Add `LinkingTo: Rcpp` and `Imports: Rcpp` in DESCRIPTION.
//   - Run `Rcpp::compileAttributes()` from the package root.
//   - Rebuild and reinstall the package.

#include <Rcpp.h>

using namespace Rcpp;

// [[Rcpp::export]]
NumericVector kwf_weighted_average_cpp(NumericMatrix curves,
                                       NumericVector weights) {
  // curves: matrix with one daily curve per row,
  //         time points in columns.
  // weights: vector of non negative weights with length equal
  //          to the number of rows in `curves`.
  //
  // The function returns a numeric vector that represents a
  // weighted average curve. Weights are rescaled to sum to one.

  if (curves.nrow() == 0 || curves.ncol() == 0) {
    stop("`curves` must have positive dimensions.");
  }

  if (weights.size() != curves.nrow()) {
    stop("`weights` length must equal number of rows in `curves`.");
  }

  int n_curves = curves.nrow();
  int n_time = curves.ncol();

  // Compute total weight
  double w_total = 0.0;
  for (int i = 0; i < n_curves; ++i) {
    double w = weights[i];
    if (w < 0.0) {
      stop("Weights must be non negative.");
    }
    w_total += w;
  }

  if (w_total <= 0.0) {
    stop("Sum of weights must be positive.");
  }

  // Output vector
  NumericVector result(n_time);
  for (int j = 0; j < n_time; ++j) {
    result[j] = 0.0;
  }

  // Accumulate weighted sum
  for (int i = 0; i < n_curves; ++i) {
    double w = weights[i] / w_total;
    for (int j = 0; j < n_time; ++j) {
      result[j] += w * curves(i, j);
    }
  }

  return result;
}
