#' Fit a clustered KWF model for daily load curves
#'
#' Cluster dyadically resampled daily curves in a wavelet-energy feature space
#' and use the resulting cluster labels as the grouping structure inside the
#' KWF forecast.
#'
#' @param segments Matrix or data frame of past daily load curves in
#'   chronological order.
#' @param covariates Optional data frame with one row per segment.
#' @param target_covariates Optional one-row data frame for the target day.
#' @param wavelet Wavelet filter name passed to [wavelets::dwt()]. Defaults to
#'   `"la12"`.
#' @param bandwidth Optional positive bandwidth for the Gaussian kernel in the
#'   underlying KWF fit.
#' @param use_mean_correction Logical; if `TRUE`, apply the approximation/detail
#'   correction in the underlying KWF fit.
#' @param max_clusters Maximum number of candidate clusters considered by the
#'   Sugar jump heuristic.
#' @param nstart Number of random starts for `kmeans`.
#' @param cluster_seed Deprecated and ignored. Clustered KWF now uses
#'   deterministic non-random starts.
#' @param weights Optional prior weights passed through to the base KWF fit.
#' @param recency_decay Optional recency prior passed through to the base KWF
#'   fit.
#' @param clustering Optional `elcf4r_kwf_clusters` object. When supplied, the
#'   stored clustering model is reused instead of being refit.
#'
#' @return An object of class `elcf4r_model` with `method = "kwf_clustered"`.
#' @export
elcf4r_fit_kwf_clustered <- function(
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
) {
  segments <- .elcf4r_as_numeric_matrix(segments, "segments")
  n_segments <- nrow(segments)

  if (n_segments < 3L) {
    stop("`segments` must contain at least three days for clustered KWF.")
  }

  if (!is.null(covariates)) {
    covariates <- as.data.frame(covariates, stringsAsFactors = FALSE)
    if (nrow(covariates) != n_segments) {
      stop("`covariates` must have one row per training segment.")
    }
  }
  if (!is.null(target_covariates)) {
    target_covariates <- as.data.frame(target_covariates, stringsAsFactors = FALSE)
    if (nrow(target_covariates) != 1L) {
      stop("`target_covariates` must have exactly one row.")
    }
  }

  if (is.null(clustering)) {
    clustering <- elcf4r_kwf_cluster_days(
      segments = segments,
      wavelet = wavelet,
      max_clusters = max_clusters,
      nstart = nstart,
      cluster_seed = cluster_seed
    )
  } else if (!inherits(clustering, "elcf4r_kwf_clusters")) {
    stop("`clustering` must inherit from `elcf4r_kwf_clusters`.")
  }

  cluster_labels <- elcf4r_assign_kwf_clusters(clustering, segments)
  target_group <- elcf4r_assign_kwf_clusters(
    clustering,
    segments[n_segments, , drop = FALSE]
  )[[1L]]

  clustered_covariates <- if (is.null(covariates)) {
    data.frame(kwf_group = cluster_labels, stringsAsFactors = FALSE)
  } else {
    covariates
  }
  clustered_covariates$kwf_group <- cluster_labels

  clustered_target_covariates <- if (is.null(target_covariates)) {
    data.frame(kwf_group = target_group, stringsAsFactors = FALSE)
  } else {
    target_covariates
  }
  clustered_target_covariates$kwf_group <- target_group

  fit <- elcf4r_fit_kwf(
    segments = segments,
    covariates = clustered_covariates,
    target_covariates = clustered_target_covariates,
    wavelet = clustering$wavelet,
    bandwidth = bandwidth,
    use_mean_correction = use_mean_correction,
    group_col = "kwf_group",
    weights = weights,
    recency_decay = recency_decay
  )

  fit$method <- "kwf_clustered"
  fit$cluster_assignments <- cluster_labels
  fit$cluster_target_group <- target_group
  fit$cluster_k <- clustering$cluster_k
  fit$cluster_jump_values <- clustering$cluster_jump_values
  fit$cluster_feature_names <- clustering$feature_names
  fit$cluster_feature_scores <- clustering$feature_scores
  fit$cluster_centers <- clustering$cluster_centers
  fit$cluster_seed <- clustering$cluster_seed
  fit$clustering <- clustering

  fit
}

.elcf4r_kwf_cluster_features <- function(decomposed_segments) {
  features <- t(
    vapply(
      decomposed_segments,
      function(x) {
        vapply(
          x$detail_coeffs,
          function(dj) sum(as.numeric(dj)^2),
          numeric(1)
        )
      },
      numeric(length(decomposed_segments[[1L]]$detail_coeffs))
    )
  )

  colnames(features) <- paste0("ac_level_", seq_len(ncol(features)))
  features
}

.elcf4r_kwf_select_features <- function(features, cluster_seed = NULL) {
  features <- as.matrix(features)
  storage.mode(features) <- "double"

  if (ncol(features) == 1L) {
    scales <- 1
    centers <- as.numeric(colMeans(features))
    scaled <- matrix(features - centers, ncol = 1L)
    colnames(scaled) <- colnames(features)
    return(
      list(
        raw_features = features,
        scaled_features = scaled,
        feature_names = colnames(features),
        selected_index = 1L,
        scores = 1,
        centers = centers,
        scales = scales
      )
    )
  }

  feature_scores <- vapply(
    seq_len(ncol(features)),
    function(j) {
      x <- as.numeric(features[, j])
      if (length(unique(round(x, 10))) < 2L) {
        return(0)
      }
      km <- .elcf4r_kmeans_fit(
        x = matrix(x, ncol = 1L),
        centers = 2L,
        nstart = 10L
      )
      if (!is.finite(km$totss) || km$totss <= 0) {
        return(0)
      }
      km$betweenss / km$totss
    },
    numeric(1)
  )

  keep <- which(feature_scores > 0.05)
  if (length(keep) == 0L) {
    keep <- which.max(feature_scores)
  }

  ordered_keep <- keep[order(feature_scores[keep], decreasing = TRUE)]
  selected <- integer()
  if (length(ordered_keep) > 0L) {
    cor_mat <- suppressWarnings(stats::cor(features[, ordered_keep, drop = FALSE]))
    if (length(ordered_keep) == 1L) {
      selected <- ordered_keep
    } else {
      for (idx in seq_along(ordered_keep)) {
        candidate <- ordered_keep[[idx]]
        if (length(selected) == 0L) {
          selected <- c(selected, candidate)
        } else {
          local_idx <- match(candidate, ordered_keep)
          prior_idx <- match(selected, ordered_keep)
          max_abs_cor <- max(abs(cor_mat[local_idx, prior_idx]), na.rm = TRUE)
          if (!is.finite(max_abs_cor) || max_abs_cor < 0.95) {
            selected <- c(selected, candidate)
          }
        }
      }
    }
  }
  if (length(selected) == 0L) {
    selected <- ordered_keep[[1L]]
  }

  raw_selected <- features[, selected, drop = FALSE]
  centers <- colMeans(raw_selected)
  scales <- apply(raw_selected, 2L, stats::sd)
  scales[!is.finite(scales) | scales <= 0] <- 1
  scaled <- sweep(raw_selected, 2L, centers, "-", check.margin = FALSE)
  scaled <- sweep(scaled, 2L, scales, "/", check.margin = FALSE)

  list(
    raw_features = raw_selected,
    scaled_features = scaled,
    feature_names = colnames(raw_selected),
    selected_index = selected,
    scores = feature_scores[selected],
    centers = centers,
    scales = scales
  )
}

.elcf4r_kwf_select_k_jump <- function(
    features,
    max_clusters = 10L,
    nstart = 30L,
    cluster_seed = NULL
) {
  features <- as.matrix(features)
  n <- nrow(features)
  p <- ncol(features)
  n_distinct <- nrow(unique(features))

  if (n < 2L) {
    return(list(k = 1L, distortions = 0, transformed = 0, jumps = NA_real_))
  }

  max_k <- min(as.integer(max_clusters), n - 1L, n_distinct)
  if (!is.finite(max_k) || max_k < 1L) {
    max_k <- 1L
  }

  distortions <- vapply(
    seq_len(max_k),
    function(k) {
      km <- .elcf4r_kmeans_fit(
        x = features,
        centers = k,
        nstart = nstart
      )
      sum(km$withinss) / (n * max(p, 1L))
    },
    numeric(1)
  )

  distortions[!is.finite(distortions) | distortions <= 0] <- 1e-12
  transformed <- distortions^(-p / 2)
  jumps <- c(NA_real_, diff(transformed))

  if (max_k == 1L || all(!is.finite(jumps[-1L])) || max(jumps[-1L], na.rm = TRUE) <= 0) {
    k <- 1L
  } else {
    k <- which.max(jumps[-1L]) + 1L
  }

  list(
    k = as.integer(k),
    distortions = distortions,
    transformed = transformed,
    jumps = jumps
  )
}
