#' Cluster daily segments for clustered KWF
#'
#' Build a reusable clustering model for daily load-curve segments in the
#' wavelet-energy feature space used by the clustered KWF workflow.
#'
#' @param segments Matrix or data frame of daily load curves in chronological
#'   order.
#' @param wavelet Wavelet filter name passed to [wavelets::dwt()]. Defaults to
#'   `"la12"`.
#' @param max_clusters Maximum number of candidate clusters considered by the
#'   Sugar jump heuristic.
#' @param nstart Number of random starts for `kmeans`.
#' @param cluster_seed Optional integer seed used to make clustering
#'   deterministic.
#'
#' @return An object of class `elcf4r_kwf_clusters`.
#' @export
elcf4r_kwf_cluster_days <- function(
    segments,
    wavelet = "la12",
    max_clusters = 10L,
    nstart = 30L,
    cluster_seed = 1L
) {
  segments <- .elcf4r_as_numeric_matrix(segments, "segments")
  n_segments <- nrow(segments)
  n_time <- ncol(segments)

  if (n_segments < 2L) {
    stop("`segments` must contain at least two days for KWF clustering.")
  }

  dyadic_points <- .elcf4r_next_power_of_two(n_time)
  wavelet_used <- .elcf4r_kwf_resolve_filter(
    wavelet = wavelet,
    dyadic_points = dyadic_points
  )
  n_levels <- as.integer(log(dyadic_points, base = 2))

  dyadic_segments <- t(
    vapply(
      seq_len(n_segments),
      function(i) {
        .elcf4r_resample_signal(segments[i, ], out_points = dyadic_points)
      },
      numeric(dyadic_points)
    )
  )

  decomposed <- lapply(
    seq_len(n_segments),
    function(i) {
      .elcf4r_kwf_decompose_segment(
        segment = dyadic_segments[i, ],
        wavelet = wavelet_used,
        n_levels = n_levels
      )
    }
  )

  cluster_features <- .elcf4r_kwf_cluster_features(decomposed)
  selected <- .elcf4r_kwf_select_features(
    cluster_features,
    cluster_seed = cluster_seed
  )
  clustering_input <- selected$scaled_features

  k_info <- .elcf4r_kwf_select_k_jump(
    features = clustering_input,
    max_clusters = max_clusters,
    nstart = nstart,
    cluster_seed = cluster_seed
  )
  km <- .elcf4r_with_seed(
    cluster_seed + 2000L,
    stats::kmeans(
      x = clustering_input,
      centers = k_info$k,
      nstart = as.integer(nstart)
    )
  )

  labels <- paste0("cluster_", km$cluster)

  structure(
    list(
      method = "kwf_clustering",
      wavelet = wavelet_used,
      requested_wavelet = as.character(wavelet)[1L],
      dyadic_points = dyadic_points,
      n_levels = n_levels,
      feature_names = selected$feature_names,
      feature_scores = selected$scores,
      feature_centers = selected$centers,
      feature_scales = selected$scales,
      cluster_centers = km$centers,
      cluster_labels = labels,
      cluster_index = km$cluster,
      cluster_k = k_info$k,
      cluster_jump_values = k_info$jumps,
      cluster_distortions = k_info$distortions,
      nstart = as.integer(nstart),
      cluster_seed = as.integer(cluster_seed),
      n_segments = n_segments,
      n_time = n_time
    ),
    class = "elcf4r_kwf_clusters"
  )
}

#' Assign new segments to a fitted KWF clustering model
#'
#' @param object An `elcf4r_kwf_clusters` object returned by
#'   `elcf4r_kwf_cluster_days()`.
#' @param segments Matrix or data frame of new daily segments.
#' @param ... Unused, present for method compatibility.
#'
#' @return A character vector of cluster labels.
#' @method predict elcf4r_kwf_clusters
#' @export
predict.elcf4r_kwf_clusters <- function(object, segments, ...) {
  if (!inherits(object, "elcf4r_kwf_clusters")) {
    stop("`object` must inherit from `elcf4r_kwf_clusters`.")
  }

  segments <- .elcf4r_as_numeric_matrix(segments, "segments")
  transformed <- .elcf4r_kwf_prepare_cluster_input(
    segments = segments,
    wavelet = object$wavelet,
    dyadic_points = object$dyadic_points,
    n_levels = object$n_levels,
    feature_names = object$feature_names,
    feature_centers = object$feature_centers,
    feature_scales = object$feature_scales
  )

  assignment_idx <- apply(
    transformed,
    1L,
    function(row) {
      distances <- rowSums((object$cluster_centers - matrix(
        row,
        nrow = nrow(object$cluster_centers),
        ncol = ncol(object$cluster_centers),
        byrow = TRUE
      ))^2)
      which.min(distances)
    }
  )

  paste0("cluster_", as.integer(assignment_idx))
}

#' Assign segments to a fitted KWF clustering model
#'
#' @param object An `elcf4r_kwf_clusters` object.
#' @param segments Matrix or data frame of daily segments.
#'
#' @return A character vector of cluster labels.
#' @export
elcf4r_assign_kwf_clusters <- function(object, segments) {
  stats::predict(object, segments = segments)
}

.elcf4r_kwf_prepare_cluster_input <- function(
    segments,
    wavelet,
    dyadic_points,
    n_levels,
    feature_names,
    feature_centers,
    feature_scales
) {
  dyadic_segments <- t(
    vapply(
      seq_len(nrow(segments)),
      function(i) {
        .elcf4r_resample_signal(segments[i, ], out_points = dyadic_points)
      },
      numeric(dyadic_points)
    )
  )

  decomposed <- lapply(
    seq_len(nrow(dyadic_segments)),
    function(i) {
      .elcf4r_kwf_decompose_segment(
        segment = dyadic_segments[i, ],
        wavelet = wavelet,
        n_levels = n_levels
      )
    }
  )
  features <- .elcf4r_kwf_cluster_features(decomposed)
  raw_selected <- features[, feature_names, drop = FALSE]
  scaled <- sweep(raw_selected, 2L, feature_centers, "-", check.margin = FALSE)
  sweep(scaled, 2L, feature_scales, "/", check.margin = FALSE)
}

.elcf4r_with_seed <- function(seed, expr) {
  if (is.null(seed) || is.na(seed)) {
    return(eval.parent(substitute(expr)))
  }

  old_seed_exists <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (old_seed_exists) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }
  on.exit({
    if (old_seed_exists) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)

  set.seed(as.integer(seed)[1L])
  eval.parent(substitute(expr))
}
