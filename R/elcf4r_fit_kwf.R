#' Fit a Kernel Wavelet Functional model for daily load curves
#'
#' Fit a day-ahead Kernel Wavelet Functional (KWF) model on ordered daily load
#' curves. The implementation computes wavelet-detail distances on the
#' historical context days, applies Gaussian kernel weights, restricts those
#' weights to matching calendar groups when available, and can apply the
#' approximation/detail correction used for mean-level non-stationarity.
#'
#' @param segments Matrix or data frame of past daily load curves
#'   (rows are days, columns are within-day time points) in chronological order.
#' @param covariates Optional data frame with one row per training segment.
#'   When present, the function looks for deterministic grouping information in
#'   `context_group`, `kwf_group`, `calendar_group`, or the column named by
#'   `group_col`. If no explicit group column is present, groups are derived from
#'   `date` and `holidays`, or from `dow` as a fallback.
#' @param target_covariates Optional one-row data frame describing the day to
#'   forecast. When it contains `date`, the previous day is used as the context
#'   day for calendar grouping, which matches the residential KWF protocol for
#'   pre-holiday handling.
#' @param use_temperature Deprecated and ignored. Kept for backward
#'   compatibility with earlier package examples.
#' @param wavelet Wavelet filter name passed to [wavelets::dwt()]. Defaults to
#'   `"la12"`, the least-asymmetric filter. If the series is too short for the 
#'   requested filter, the function falls back to `"haar"`.
#' @param bandwidth Optional positive bandwidth for the Gaussian kernel on
#'   wavelet distances. If `NULL`, it is inferred from the distances to the last
#'   observed segment.
#' @param use_mean_correction Logical; if `TRUE`, apply the approximation/detail
#'   correction used for mean-level non-stationarity.
#' @param group_col Optional column name containing precomputed KWF groups in
#'   `covariates` and `target_covariates`.
#' @param holidays Optional vector of holiday dates used by
#'   [elcf4r_calendar_groups()] when deterministic groups are derived from
#'   `date`.
#' @param weights Optional numeric prior weights of length `nrow(segments)`.
#'   Only the first `nrow(segments) - 1` values are used in the historical
#'   pairing step.
#' @param recency_decay Optional non-negative recency coefficient applied as an
#'   exponential prior on the historical context days.
#' @param temperature_bandwidth Deprecated and ignored. Kept only for backward
#'   compatibility with older examples.
#'
#' @return An object of class `elcf4r_model` with `method = "kwf"`.
#' @export
#' @examples
#' id1 <- subset(
#'   elcf4r_iflex_example,
#'   entity_id == unique(elcf4r_iflex_example$entity_id)[1]
#' )
#' daily <- elcf4r_build_daily_segments(id1, carry_cols = "participation_phase")
#' fit <- elcf4r_fit_kwf(
#'   segments = daily$segments[1:10, ],
#'   covariates = daily$covariates[1:10, ],
#'   target_covariates = daily$covariates[11, , drop = FALSE]
#' )
#' length(predict(fit))
elcf4r_fit_kwf <- function(
    segments,
    covariates = NULL,
    target_covariates = NULL,
    use_temperature = FALSE,
    wavelet = "la12",
    bandwidth = NULL,
    use_mean_correction = TRUE,
    group_col = NULL,
    holidays = NULL,
    weights = NULL,
    recency_decay = NULL,
    temperature_bandwidth = NULL
) {
  segments <- .elcf4r_as_numeric_matrix(segments, "segments")
  n_segments <- nrow(segments)
  n_time <- ncol(segments)

  if (n_segments < 2L) {
    stop("`segments` must contain at least two historical days for KWF.")
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

  current_decomp <- decomposed[[n_segments]]
  context_decomp <- decomposed[seq_len(n_segments - 1L)]
  context_features <- .elcf4r_kwf_feature_matrix(
    lapply(context_decomp, function(x) x$detail_coeffs)
  )
  target_features <- .elcf4r_kwf_feature_vector(current_decomp$detail_coeffs)
  distances <- .elcf4r_kwf_distances(
    context_features = context_features,
    target_features = target_features,
    context_decomp = context_decomp,
    target_decomp = current_decomp
  )

  kernel <- .elcf4r_kwf_kernel_weights(distances, bandwidth = bandwidth)
  prior_weights <- .elcf4r_kwf_prior_weights(
    n_segments = n_segments,
    weights = weights,
    recency_decay = recency_decay
  )
  base_weights <- kernel$weights * prior_weights

  groups <- .elcf4r_kwf_prepare_groups(
    covariates = covariates,
    target_covariates = target_covariates,
    n_segments = n_segments,
    holidays = holidays,
    group_col = group_col
  )

  final_context_weights <- .elcf4r_kwf_apply_group_restriction(
    weights = base_weights,
    context_groups = groups$context_groups,
    target_group = groups$target_group
  )
  final_context_weights <- final_context_weights / sum(final_context_weights)

  future_dyadic <- dyadic_segments[2:n_segments, , drop = FALSE]

  if (isTRUE(use_mean_correction)) {
    detail_future <- do.call(
      rbind,
      lapply(decomposed[2:n_segments], function(x) x$detail_signal)
    )
    approx_matrix <- do.call(
      rbind,
      lapply(decomposed, function(x) x$approx_signal)
    )
    approx_transitions <- approx_matrix[2:n_segments, , drop = FALSE] -
      approx_matrix[1:(n_segments - 1L), , drop = FALSE]

    forecast_dyadic <- .elcf4r_kwf_mean_corrected_forecast(
      detail_future = detail_future,
      approx_transitions = approx_transitions,
      current_approx = current_decomp$approx_signal,
      weights = final_context_weights
    )
  } else {
    forecast_dyadic <- .elcf4r_weighted_average(
      future_dyadic,
      final_context_weights
    )
  }

  fitted_curve <- .elcf4r_resample_signal(
    forecast_dyadic,
    out_points = n_time
  )

  full_weights <- c(final_context_weights, 0)

  structure(
    list(
      method = "kwf",
      fitted_curve = fitted_curve,
      n_segments = n_segments,
      n_time = n_time,
      dyadic_points = dyadic_points,
      n_levels = n_levels,
      wavelet = wavelet_used,
      requested_wavelet = as.character(wavelet)[1L],
      bandwidth = kernel$bandwidth,
      use_mean_correction = isTRUE(use_mean_correction),
      use_temperature = use_temperature,
      weights = full_weights,
      context_weights = final_context_weights,
      distances = distances,
      covariates = covariates,
      target_covariates = target_covariates,
      calendar_groups = groups$history_groups,
      target_group = groups$target_group
    ),
    class = "elcf4r_model"
  )
}

.elcf4r_kwf_decompose_segment <- function(segment, wavelet, n_levels) {
  x <- as.numeric(segment)
  wt <- wavelets::dwt(
    X = x,
    filter = wavelet,
    n.levels = n_levels,
    boundary = "periodic",
    fast = TRUE
  )
  mra <- wavelets::mra(
    X = x,
    filter = wavelet,
    n.levels = n_levels,
    boundary = "periodic",
    fast = TRUE,
    method = "dwt"
  )

  approx_signal <- as.numeric(mra@S[[length(mra@S)]])
  detail_coeffs <- lapply(wt@W, function(x) as.numeric(x))

  list(
    detail_coeffs = detail_coeffs,
    approx_signal = approx_signal,
    detail_signal = x - approx_signal
  )
}

.elcf4r_kwf_distance <- function(detail_a, detail_b) {
  if (length(detail_a) != length(detail_b)) {
    stop("Detail coefficient lists must have the same number of levels.")
  }

  level_weights <- 2^(-seq_along(detail_a) / 2)
  distance_sq <- vapply(
    seq_along(detail_a),
    function(j) {
      diff_j <- as.numeric(detail_a[[j]]) - as.numeric(detail_b[[j]])
      level_weights[[j]] * sum(diff_j^2)
    },
    numeric(1)
  )

  sqrt(sum(distance_sq))
}

.elcf4r_kwf_feature_vector <- function(detail_coeffs) {
  level_weights <- 2^(-seq_along(detail_coeffs) / 4)
  unlist(
    lapply(
      seq_along(detail_coeffs),
      function(j) level_weights[[j]] * as.numeric(detail_coeffs[[j]])
    ),
    use.names = FALSE
  )
}

.elcf4r_kwf_feature_matrix <- function(detail_coeff_list) {
  if (length(detail_coeff_list) < 1L) {
    return(matrix(0, nrow = 0L, ncol = 0L))
  }

  template <- .elcf4r_kwf_feature_vector(detail_coeff_list[[1L]])
  out <- t(
    vapply(
      detail_coeff_list,
      .elcf4r_kwf_feature_vector,
      numeric(length(template))
    )
  )
  storage.mode(out) <- "double"
  out
}

.elcf4r_kwf_distances <- function(
    context_features,
    target_features,
    context_decomp = NULL,
    target_decomp = NULL
) {
  if (exists("kwf_row_distances_cpp", mode = "function")) {
    return(as.numeric(kwf_row_distances_cpp(context_features, target_features)))
  }

  if (is.null(context_decomp) || is.null(target_decomp)) {
    diffs <- sweep(context_features, 2L, target_features, "-", check.margin = FALSE)
    return(sqrt(rowSums(diffs^2)))
  }

  vapply(
    context_decomp,
    function(x) {
      .elcf4r_kwf_distance(x$detail_coeffs, target_decomp$detail_coeffs)
    },
    numeric(1)
  )
}

.elcf4r_kwf_kernel_weights <- function(distances, bandwidth = NULL) {
  distances <- as.numeric(distances)
  if (exists("kwf_gaussian_kernel_weights_cpp", mode = "function")) {
    return(kwf_gaussian_kernel_weights_cpp(distances, bandwidth))
  }

  positive_distances <- distances[is.finite(distances) & distances > 0]

  if (is.null(bandwidth)) {
    bandwidth <- stats::median(positive_distances, na.rm = TRUE)
  }
  if (!is.finite(bandwidth) || bandwidth <= 0) {
    bandwidth <- 1
  }

  if (all(distances == 0)) {
    weights <- rep_len(1, length(distances))
  } else {
    weights <- exp(-0.5 * (distances / bandwidth)^2)
  }
  weights[!is.finite(weights)] <- 0

  if (sum(weights) <= 0) {
    weights <- rep_len(1, length(distances))
  }

  list(weights = weights, bandwidth = bandwidth)
}

.elcf4r_kwf_prior_weights <- function(
    n_segments,
    weights = NULL,
    recency_decay = NULL
) {
  n_context <- n_segments - 1L
  prior <- rep_len(1, n_context)

  if (!is.null(weights)) {
    if (!is.numeric(weights) || length(weights) != n_segments) {
      stop("`weights` must be numeric with length equal to `nrow(segments)`.")
    }
    prior <- as.numeric(weights)[seq_len(n_context)]
  }

  if (!is.null(recency_decay)) {
    recency_decay <- as.numeric(recency_decay)
    if (!is.finite(recency_decay) || recency_decay < 0) {
      stop("`recency_decay` must be NULL or a non-negative number.")
    }
    prior <- prior * exp((seq_len(n_context) - n_context) * recency_decay)
  }

  if (any(!is.finite(prior)) || any(prior < 0)) {
    stop("KWF prior weights must be finite and non-negative.")
  }
  if (sum(prior) <= 0) {
    stop("KWF prior weights must sum to a positive value.")
  }

  prior
}

.elcf4r_kwf_prepare_groups <- function(
    covariates,
    target_covariates,
    n_segments,
    holidays = NULL,
    group_col = NULL
) {
  history_groups <- NULL
  if (!is.null(covariates)) {
    history_groups <- .elcf4r_kwf_extract_groups(
      data = covariates,
      holidays = holidays,
      group_col = group_col
    )
    if (length(history_groups) != n_segments) {
      stop("Derived KWF groups must have one value per training segment.")
    }
  }

  target_group <- NA_character_
  if (!is.null(target_covariates)) {
    explicit_target <- .elcf4r_kwf_extract_groups(
      data = target_covariates,
      holidays = holidays,
      group_col = group_col,
      date_shift = -1L
    )
    if (length(explicit_target) > 0L) {
      target_group <- explicit_target[[1L]]
    }
  }

  if (is.na(target_group) && !is.null(history_groups)) {
    target_group <- history_groups[[n_segments]]
  }

  context_groups <- rep_len(NA_character_, n_segments - 1L)
  if (!is.null(history_groups)) {
    context_groups <- history_groups[seq_len(n_segments - 1L)]
  }

  list(
    history_groups = history_groups,
    context_groups = context_groups,
    target_group = target_group
  )
}

.elcf4r_kwf_extract_groups <- function(
    data,
    holidays = NULL,
    group_col = NULL,
    date_shift = 0L
) {
  if (is.null(data)) {
    return(character())
  }

  data <- as.data.frame(data, stringsAsFactors = FALSE)
  if (!is.null(group_col) && group_col %in% names(data)) {
    out <- trimws(as.character(data[[group_col]]))
    out[out == ""] <- NA_character_
    return(out)
  }

  for (candidate in c("context_group", "kwf_group", "calendar_group", "group")) {
    if (candidate %in% names(data)) {
      out <- trimws(as.character(data[[candidate]]))
      out[out == ""] <- NA_character_
      return(out)
    }
  }

  if ("date" %in% names(data)) {
    dates <- as.Date(data[["date"]]) + as.integer(date_shift)
    return(as.character(elcf4r_calendar_groups(dates, holidays = holidays)))
  }

  if ("dow" %in% names(data)) {
    return(.elcf4r_standardize_dow(data[["dow"]]))
  }

  rep_len(NA_character_, nrow(data))
}

.elcf4r_kwf_apply_group_restriction <- function(
    weights,
    context_groups,
    target_group
) {
  weights <- as.numeric(weights)

  if (length(context_groups) != length(weights)) {
    stop("`context_groups` length must match KWF context weights.")
  }
  if (all(is.na(context_groups)) || length(target_group) == 0L || is.na(target_group)) {
    return(weights)
  }

  if (exists("kwf_apply_group_restriction_cpp", mode = "function")) {
    return(as.numeric(
      kwf_apply_group_restriction_cpp(
        as.numeric(weights),
        as.character(context_groups),
        as.character(target_group[[1L]])
      )
    ))
  }

  group_matches <- as.character(context_groups) == as.character(target_group)
  group_matches[is.na(group_matches)] <- FALSE

  if (!any(group_matches)) {
    return(weights)
  }

  restricted <- weights * as.numeric(group_matches)
  if (sum(restricted) <= 0) {
    return(weights)
  }

  restricted
}

.elcf4r_kwf_mean_corrected_forecast <- function(
    detail_future,
    approx_transitions,
    current_approx,
    weights
) {
  if (exists("kwf_mean_corrected_forecast_cpp", mode = "function")) {
    return(
      kwf_mean_corrected_forecast_cpp(
        detail_future,
        approx_transitions,
        as.numeric(current_approx),
        as.numeric(weights)
      )
    )
  }

  .elcf4r_weighted_average(detail_future, weights) +
    as.numeric(current_approx) +
    .elcf4r_weighted_average(approx_transitions, weights)
}

.elcf4r_kwf_resolve_filter <- function(wavelet, dyadic_points) {
  wavelet <- trimws(tolower(as.character(wavelet)[1L]))
  if (identical(wavelet, "sym6")) {
    wavelet <- "la12"
  }

  filter <- tryCatch(
    wavelets::wt.filter(wavelet),
    error = function(e) {
      stop("Unsupported KWF wavelet filter `", wavelet, "`.")
    }
  )

  if (dyadic_points < filter@L) {
    return("haar")
  }

  wavelet
}

.elcf4r_next_power_of_two <- function(n) {
  n <- as.integer(n)[1L]
  if (!is.finite(n) || n < 1L) {
    stop("`n` must be a positive integer.")
  }

  as.integer(2^(ceiling(log(n, base = 2))))
}

.elcf4r_resample_signal <- function(x, out_points) {
  x <- as.numeric(x)
  out_points <- as.integer(out_points)[1L]

  if (length(x) == out_points) {
    return(x)
  }

  old_grid <- seq(0, 1, length.out = length(x))
  new_grid <- seq(0, 1, length.out = out_points)
  as.numeric(
    stats::approx(
      x = old_grid,
      y = x,
      xout = new_grid,
      method = "linear",
      ties = "ordered"
    )$y
  )
}

.elcf4r_standardize_dow <- function(x) {
  x <- trimws(tolower(as.character(x)))
  map <- c(
    mon = "monday",
    monday = "monday",
    tue = "tuesday",
    tues = "tuesday",
    tuesday = "tuesday",
    wed = "wednesday",
    wednesday = "wednesday",
    thu = "thursday",
    thur = "thursday",
    thurs = "thursday",
    thursday = "thursday",
    fri = "friday",
    friday = "friday",
    sat = "saturday",
    saturday = "saturday",
    sun = "sunday",
    sunday = "sunday"
  )

  standardized <- unname(map[x])
  standardized[is.na(standardized)] <- x[is.na(standardized)]
  standardized
}

.elcf4r_as_numeric_matrix <- function(x, arg) {
  if (is.data.frame(x)) {
    x <- as.matrix(x)
  }
  if (!is.matrix(x) || !is.numeric(x)) {
    stop("`", arg, "` must be a numeric matrix or data frame.")
  }
  if (nrow(x) < 1L || ncol(x) < 1L) {
    stop("`", arg, "` must have at least one row and one column.")
  }
  storage.mode(x) <- "double"
  x
}

.elcf4r_weighted_average <- function(segments, weights) {
  weights <- as.numeric(weights)
  if (length(weights) != nrow(segments)) {
    stop("`weights` length must match the number of rows in `segments`.")
  }
  if (any(!is.finite(weights)) || any(weights < 0)) {
    stop("`weights` must be finite and non-negative.")
  }
  if (sum(weights) <= 0) {
    stop("Sum of `weights` must be positive.")
  }

  if (exists("kwf_weighted_average_cpp", mode = "function")) {
    return(kwf_weighted_average_cpp(segments, weights))
  }

  colSums(segments * weights) / sum(weights)
}
