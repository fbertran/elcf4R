#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <numeric>
#include <vector>

using namespace Rcpp;

namespace {

double compute_positive_median(const NumericVector& x) {
  std::vector<double> values;
  values.reserve(x.size());
  for (R_xlen_t i = 0; i < x.size(); ++i) {
    if (R_finite(x[i]) && x[i] > 0.0) {
      values.push_back(x[i]);
    }
  }

  if (values.empty()) {
    return NA_REAL;
  }

  std::sort(values.begin(), values.end());
  const std::size_t n = values.size();
  if (n % 2U == 1U) {
    return values[n / 2U];
  }
  return 0.5 * (values[n / 2U - 1U] + values[n / 2U]);
}

NumericVector normalize_weights(const NumericVector& weights) {
  double w_total = 0.0;
  NumericVector out(weights.size());
  for (R_xlen_t i = 0; i < weights.size(); ++i) {
    double w = weights[i];
    if (!R_finite(w)) {
      stop("Weights must be finite.");
    }
    if (w < 0.0) {
      stop("Weights must be non-negative.");
    }
    w_total += w;
  }
  if (w_total <= 0.0) {
    stop("Sum of weights must be positive.");
  }
  for (R_xlen_t i = 0; i < weights.size(); ++i) {
    out[i] = weights[i] / w_total;
  }
  return out;
}

}  // namespace

// [[Rcpp::export]]
NumericVector kwf_weighted_average_cpp(NumericMatrix curves,
                                       NumericVector weights) {
  if (curves.nrow() == 0 || curves.ncol() == 0) {
    stop("`curves` must have positive dimensions.");
  }
  if (weights.size() != curves.nrow()) {
    stop("`weights` length must equal number of rows in `curves`.");
  }

  NumericVector w = normalize_weights(weights);
  const int n_curves = curves.nrow();
  const int n_time = curves.ncol();
  NumericVector result(n_time);

  for (int i = 0; i < n_curves; ++i) {
    for (int j = 0; j < n_time; ++j) {
      result[j] += w[i] * curves(i, j);
    }
  }

  return result;
}

// [[Rcpp::export]]
NumericVector kwf_row_distances_cpp(NumericMatrix features,
                                    NumericVector target) {
  if (features.ncol() != target.size()) {
    stop("`target` length must match the number of feature columns.");
  }

  const int n_rows = features.nrow();
  const int n_cols = features.ncol();
  NumericVector out(n_rows);

  for (int i = 0; i < n_rows; ++i) {
    double acc = 0.0;
    for (int j = 0; j < n_cols; ++j) {
      double diff = features(i, j) - target[j];
      acc += diff * diff;
    }
    out[i] = std::sqrt(acc);
  }

  return out;
}

// [[Rcpp::export]]
List kwf_gaussian_kernel_weights_cpp(NumericVector distances,
                                     Nullable<double> bandwidth = R_NilValue) {
  double bw;
  if (bandwidth.isNotNull()) {
    bw = Rcpp::as<double>(bandwidth);
  } else {
    bw = compute_positive_median(distances);
  }
  if (!R_finite(bw) || bw <= 0.0) {
    bw = 1.0;
  }

  NumericVector weights(distances.size());
  bool all_zero = true;
  for (R_xlen_t i = 0; i < distances.size(); ++i) {
    if (distances[i] != 0.0) {
      all_zero = false;
      break;
    }
  }

  if (all_zero) {
    std::fill(weights.begin(), weights.end(), 1.0);
  } else {
    for (R_xlen_t i = 0; i < distances.size(); ++i) {
      if (!R_finite(distances[i])) {
        weights[i] = 0.0;
      } else {
        double z = distances[i] / bw;
        weights[i] = std::exp(-0.5 * z * z);
      }
    }
  }

  double total = std::accumulate(weights.begin(), weights.end(), 0.0);
  if (!(total > 0.0)) {
    std::fill(weights.begin(), weights.end(), 1.0);
  }

  return List::create(
    _["weights"] = weights,
    _["bandwidth"] = bw
  );
}

// [[Rcpp::export]]
NumericVector kwf_apply_group_restriction_cpp(NumericVector weights,
                                              CharacterVector context_groups,
                                              CharacterVector target_group) {
  if (weights.size() != context_groups.size()) {
    stop("`context_groups` length must match `weights`.");
  }
  if (target_group.size() == 0) {
    return weights;
  }

  if (target_group[0] == NA_STRING) {
    return weights;
  }

  NumericVector out = clone(weights);
  for (R_xlen_t i = 0; i < out.size(); ++i) {
    if (context_groups[i] == NA_STRING) {
      out[i] = 0.0;
    } else if (context_groups[i] != target_group[0]) {
      out[i] = 0.0;
    }
  }

  double total = std::accumulate(out.begin(), out.end(), 0.0);
  if (total <= 0.0) {
    return weights;
  }
  return out;
}

// [[Rcpp::export]]
NumericVector kwf_mean_corrected_forecast_cpp(NumericMatrix detail_future,
                                              NumericMatrix approx_transitions,
                                              NumericVector current_approx,
                                              NumericVector weights) {
  if (detail_future.nrow() != approx_transitions.nrow() ||
      detail_future.ncol() != approx_transitions.ncol()) {
    stop("`detail_future` and `approx_transitions` must have the same dimensions.");
  }
  if (detail_future.nrow() != weights.size()) {
    stop("`weights` length must match the number of historical rows.");
  }
  if (detail_future.ncol() != current_approx.size()) {
    stop("`current_approx` length must match the number of time points.");
  }

  NumericVector w = normalize_weights(weights);
  const int n_rows = detail_future.nrow();
  const int n_cols = detail_future.ncol();
  NumericVector out = clone(current_approx);

  for (int i = 0; i < n_rows; ++i) {
    const double wi = w[i];
    for (int j = 0; j < n_cols; ++j) {
      out[j] += wi * (detail_future(i, j) + approx_transitions(i, j));
    }
  }

  return out;
}
