#' Build a day-level benchmark index from a normalized panel
#'
#' Create a compact day-level index from a normalized panel. The returned object
#' contains one row per complete entity-day and can be reused to define
#' deterministic benchmark cohorts without shipping the full panel.
#'
#' @param data Normalized panel data, typically returned by one of the
#'   `elcf4r_read_*()` adapters.
#' @param carry_cols Optional character vector of additional day-level columns
#'   to propagate into the benchmark index. If `NULL`, all non-core columns are
#'   carried.
#' @param id_col Name of the entity identifier column.
#' @param timestamp_col Name of the timestamp column.
#' @param value_col Name of the load column.
#' @param temp_col Name of the temperature column.
#' @param resolution_minutes Sampling resolution in minutes. If `NULL`, it is
#'   inferred from the data.
#' @param complete_days_only Passed to [elcf4r_build_daily_segments()].
#' @param drop_na_value Passed to [elcf4r_build_daily_segments()].
#' @param tz Time zone used to derive dates and within-day positions.
#'
#' @return A day-level data frame suitable for `elcf4r_benchmark()`.
#' @export
#' @examples
#' idx <- elcf4r_build_benchmark_index(
#'   elcf4r_iflex_example,
#'   carry_cols = c("dataset", "participation_phase", "price_signal")
#' )
#' head(idx)
elcf4r_build_benchmark_index <- function(
    data,
    carry_cols = NULL,
    id_col = "entity_id",
    timestamp_col = "timestamp",
    value_col = "y",
    temp_col = "temp",
    resolution_minutes = NULL,
    complete_days_only = TRUE,
    drop_na_value = TRUE,
    tz = "UTC"
) {
  stopifnot(is.data.frame(data))

  core_cols <- unique(c(
    id_col,
    timestamp_col,
    value_col,
    temp_col,
    "dataset",
    "date",
    "time_index",
    "dow",
    "month",
    "resolution_minutes"
  ))
  if (is.null(carry_cols)) {
    carry_cols <- setdiff(names(data), stats::na.omit(core_cols))
  }

  daily <- elcf4r_build_daily_segments(
    data = data,
    id_col = id_col,
    timestamp_col = timestamp_col,
    value_col = value_col,
    temp_col = temp_col,
    carry_cols = carry_cols,
    resolution_minutes = resolution_minutes,
    complete_days_only = complete_days_only,
    drop_na_value = drop_na_value,
    tz = tz
  )

  index <- daily$covariates
  keep_cols <- unique(c(
    "day_key",
    id_col,
    "date",
    "dow",
    "month",
    "temp_mean",
    "temp_min",
    "temp_max",
    carry_cols,
    "n_points"
  ))
  keep_cols <- intersect(keep_cols, names(index))
  index <- index[, keep_cols, drop = FALSE]

  if (!identical(id_col, "entity_id") && id_col %in% names(index)) {
    names(index)[names(index) == id_col] <- "entity_id"
  }

  ord <- order(index[["entity_id"]], index[["date"]])
  index <- index[ord, , drop = FALSE]
  rownames(index) <- NULL
  index
}

.elcf4r_slice_benchmark_index <- function(
    benchmark_index,
    required_days,
    entity_ids = NULL,
    anchor = c("first", "last"),
    start_date = NULL,
    end_date = NULL
) {
  stopifnot(is.data.frame(benchmark_index))

  anchor <- match.arg(anchor)
  required_days <- as.integer(required_days)[1L]
  if (!is.finite(required_days) || required_days < 1L) {
    stop("`required_days` must be a positive integer.")
  }

  idx <- as.data.frame(benchmark_index, stringsAsFactors = FALSE)
  idx[["date"]] <- as.Date(idx[["date"]])
  idx <- idx[order(idx[["entity_id"]], idx[["date"]]), , drop = FALSE]

  if (!is.null(entity_ids)) {
    idx <- idx[idx[["entity_id"]] %in% as.character(entity_ids), , drop = FALSE]
  }
  if (!is.null(start_date)) {
    idx <- idx[idx[["date"]] >= as.Date(start_date), , drop = FALSE]
  }
  if (!is.null(end_date)) {
    idx <- idx[idx[["date"]] <= as.Date(end_date), , drop = FALSE]
  }

  split_idx <- split(idx, idx[["entity_id"]])
  kept <- lapply(
    split_idx,
    function(x) {
      if (nrow(x) < required_days) {
        return(NULL)
      }
      if (identical(anchor, "last")) {
        utils::tail(x, required_days)
      } else {
        utils::head(x, required_days)
      }
    }
  )
  kept <- Filter(Negate(is.null), kept)
  if (length(kept) < 1L) {
    return(idx[0, , drop = FALSE])
  }

  out <- do.call(rbind, kept)
  rownames(out) <- NULL
  out
}

#' Run a rolling-origin benchmark on a normalized panel
#'
#' Evaluate the package forecasting methods on a normalized panel using a
#' deterministic rolling-origin design. The runner supports the current
#' temperature-aware `gam`, `mars`, `kwf`, `kwf_clustered` and `lstm` wrappers
#' and returns both aggregate scores and, optionally, saved point forecasts.
#'
#' @param panel Normalized panel data, typically returned by one of the
#'   `elcf4r_read_*()` adapters.
#' @param benchmark_index Optional day-level index. If `NULL`, it is created
#'   with `elcf4r_build_benchmark_index()`.
#' @param methods Character vector of method names to evaluate. Supported values
#'   are `"gam"`, `"mars"`, `"kwf"`, `"kwf_clustered"` and `"lstm"`. If
#'   `NULL`, the runner uses `gam`, `mars`, `kwf`, `kwf_clustered` and adds
#'   `lstm` only when its backend is available.
#' @param entity_ids Optional character vector of entity IDs to benchmark.
#' @param cohort_size Optional maximum number of eligible entities to keep after
#'   sorting by `entity_id`.
#' @param train_days Number of days in each training window.
#' @param test_days Number of one-day rolling test origins per entity.
#' @param benchmark_name Optional benchmark identifier. If `NULL`, one is
#'   derived from the dataset label and benchmark design.
#' @param dataset Optional dataset label overriding `unique(panel$dataset)`.
#' @param use_temperature Logical; if `TRUE`, methods that support temperature
#'   will use it when non-missing temperature information is available for the
#'   current window.
#' @param method_args Optional named list of per-method argument overrides.
#' @param include_predictions Logical; if `TRUE`, return a long table of saved
#'   point forecasts and naive forecasts.
#' @param thermosensitivity_panel Optional normalized panel used for
#'   thermosensitivity classification. Defaults to `panel`.
#' @param benchmark_index_carry_cols Optional `carry_cols` passed to
#'   `elcf4r_build_benchmark_index()` when `benchmark_index` is not supplied.
#' @param seed Optional integer seed forwarded to methods that support
#'   user-supplied seeding, such as LSTM, unless overridden in `method_args`.
#' @param tz Time zone used to derive dates and within-day positions.
#'
#' @return An object of class `elcf4r_benchmark` with elements `results`,
#'   `predictions`, `cohort_index`, `spec` and `backend`.
#' @export
#' @examples
#' id1 <- subset(
#'   elcf4r_iflex_example,
#'   entity_id == unique(elcf4r_iflex_example$entity_id)[1]
#' )
#' keep_dates <- sort(unique(id1$date))[1:6]
#' panel_small <- subset(id1, date %in% keep_dates)
#' bench <- elcf4r_benchmark(
#'   panel = panel_small,
#'   methods = "gam",
#'   cohort_size = 1,
#'   train_days = 4,
#'   test_days = 1,
#'   include_predictions = TRUE
#' )
#' head(bench$results)
elcf4r_benchmark <- function(
    panel,
    benchmark_index = NULL,
    methods = NULL,
    entity_ids = NULL,
    cohort_size = NULL,
    train_days = 28L,
    test_days = 5L,
    benchmark_name = NULL,
    dataset = NULL,
    use_temperature = TRUE,
    method_args = NULL,
    include_predictions = TRUE,
    thermosensitivity_panel = NULL,
    benchmark_index_carry_cols = NULL,
    seed = NULL,
    tz = "UTC"
) {
  stopifnot(is.data.frame(panel))

  train_days <- as.integer(train_days)
  test_days <- as.integer(test_days)
  if (!is.null(seed)) {
    seed <- as.integer(seed)[1L]
    if (!is.finite(seed)) {
      stop("`seed` must be NULL or a finite integer.")
    }
  }

  if (train_days < 1L) {
    stop("`train_days` must be at least 1.")
  }
  if (test_days < 1L) {
    stop("`test_days` must be at least 1.")
  }

  if (is.null(thermosensitivity_panel)) {
    thermosensitivity_panel <- panel
  }
  thermosensitivity_panel <- as.data.frame(thermosensitivity_panel, stringsAsFactors = FALSE)
  panel <- as.data.frame(panel, stringsAsFactors = FALSE)

  required_panel_cols <- c("entity_id", "timestamp", "date", "time_index", "y")
  missing_panel_cols <- setdiff(required_panel_cols, names(panel))
  if (length(missing_panel_cols) > 0L) {
    stop("`panel` is missing required columns: ", paste(missing_panel_cols, collapse = ", "))
  }

  if (is.null(benchmark_index)) {
    benchmark_index <- elcf4r_build_benchmark_index(
      data = panel,
      carry_cols = benchmark_index_carry_cols,
      tz = tz
    )
  } else {
    benchmark_index <- as.data.frame(benchmark_index, stringsAsFactors = FALSE)
  }

  if (!"day_key" %in% names(benchmark_index)) {
    if (!all(c("entity_id", "date") %in% names(benchmark_index))) {
      stop("`benchmark_index` must contain `day_key` or both `entity_id` and `date`.")
    }
    benchmark_index[["day_key"]] <- paste(
      benchmark_index[["entity_id"]],
      as.Date(benchmark_index[["date"]]),
      sep = "__"
    )
  }
  benchmark_index[["date"]] <- as.Date(benchmark_index[["date"]])
  ord <- order(benchmark_index[["entity_id"]], benchmark_index[["date"]])
  benchmark_index <- benchmark_index[ord, , drop = FALSE]
  rownames(benchmark_index) <- NULL

  dataset_label <- dataset
  if (is.null(dataset_label)) {
    dataset_values <- unique(stats::na.omit(as.character(panel[["dataset"]])))
    dataset_label <- if (length(dataset_values) == 1L) dataset_values[[1L]] else "panel"
  }

  backend <- .elcf4r_benchmark_backend_info()
  default_methods <- c("gam", "mars", "kwf", "kwf_clustered")
  if (isTRUE(backend$lstm_backend_available)) {
    default_methods <- c(default_methods, "lstm")
  }
  if (is.null(methods)) {
    methods <- default_methods
  }
  methods <- as.character(methods)
  supported_methods <- c("gam", "mars", "kwf", "kwf_clustered", "lstm")
  unknown_methods <- setdiff(methods, supported_methods)
  if (length(unknown_methods) > 0L) {
    stop("Unsupported benchmark methods: ", paste(unknown_methods, collapse = ", "))
  }

  required_days <- train_days + test_days
  days_per_id <- table(benchmark_index[["entity_id"]])
  eligible_ids <- sort(names(days_per_id[days_per_id >= required_days]))
  if (!is.null(entity_ids)) {
    entity_ids <- as.character(entity_ids)
    eligible_ids <- entity_ids[entity_ids %in% eligible_ids]
  }
  if (length(eligible_ids) == 0L) {
    stop("No eligible entities have at least ", required_days, " complete days.")
  }
  if (!is.null(cohort_size)) {
    cohort_size <- as.integer(cohort_size)[1L]
    eligible_ids <- utils::head(eligible_ids, cohort_size)
  }

  selected_index <- do.call(
    rbind,
    lapply(
      eligible_ids,
      function(id) {
        utils::head(
          benchmark_index[benchmark_index[["entity_id"]] == id, , drop = FALSE],
          required_days
        )
      }
    )
  )
  rownames(selected_index) <- NULL

  selected_day_keys <- selected_index[["day_key"]]
  panel_day_keys <- paste(panel[["entity_id"]], panel[["date"]], sep = "__")
  panel <- panel[panel_day_keys %in% selected_day_keys, , drop = FALSE]
  panel <- panel[order(panel[["entity_id"]], panel[["timestamp"]]), , drop = FALSE]
  rownames(panel) <- NULL

  if (is.null(benchmark_name)) {
    resolution_values <- unique(stats::na.omit(as.numeric(panel[["resolution_minutes"]])))
    resolution_label <- if (length(resolution_values) == 1L) {
      .elcf4r_benchmark_resolution_label(resolution_values[[1L]])
    } else {
      "mixed"
    }
    benchmark_name <- paste0(
      dataset_label, "_", resolution_label, "_",
      length(eligible_ids), "_ids_",
      train_days, "_train_",
      test_days, "_test_",
      length(methods), "_methods"
    )
  }

  result_rows <- vector("list", length = length(eligible_ids) * test_days * length(methods))
  prediction_rows <- vector("list", length = length(eligible_ids) * test_days * length(methods))
  row_id <- 1L

  for (id in eligible_ids) {
    id_index <- selected_index[selected_index[["entity_id"]] == id, , drop = FALSE]
    id_days <- id_index[["date"]]
    id_panel <- panel[panel[["entity_id"]] == id, , drop = FALSE]
    id_thermo_panel <- thermosensitivity_panel[
      thermosensitivity_panel[["entity_id"]] == id,
      c("entity_id", "date", "y"),
      drop = FALSE
    ]

    for (test_offset in seq_len(test_days)) {
      test_pos <- train_days + test_offset
      train_dates <- id_days[(test_pos - train_days):(test_pos - 1L)]
      test_date <- id_days[[test_pos]]

      train_panel <- id_panel[id_panel[["date"]] %in% train_dates, , drop = FALSE]
      test_panel <- id_panel[id_panel[["date"]] == test_date, , drop = FALSE]

      train_long <- .elcf4r_benchmark_long_data(train_panel)
      test_long <- .elcf4r_benchmark_long_data(test_panel)
      aligned_long <- .elcf4r_benchmark_align_temporal_factors(train_long, test_long)
      train_long <- aligned_long$train
      test_long <- aligned_long$test
      use_temp_window <- isTRUE(use_temperature) &&
        .elcf4r_benchmark_has_temperature(train_long, test_long)

      train_segments <- .elcf4r_benchmark_panel_to_segments(train_panel)
      test_segments <- .elcf4r_benchmark_panel_to_segments(test_panel)
      train_covariates <- id_index[id_index[["date"]] %in% train_dates, , drop = FALSE]
      train_covariates <- train_covariates[
        match(as.Date(rownames(train_segments)), train_covariates[["date"]]),
        ,
        drop = FALSE
      ]
      test_covariates <- id_index[id_index[["date"]] == test_date, , drop = FALSE]

      thermo_subset <- id_thermo_panel[
        id_thermo_panel[["date"]] <= max(train_dates),
        ,
        drop = FALSE
      ]
      thermo_info <- elcf4r_classify_thermosensitivity(thermo_subset)
      thermosensitive <- thermo_info$thermosensitive[[1L]]
      thermosensitivity_status <- thermo_info$status[[1L]]
      thermosensitivity_ratio <- thermo_info$ratio[[1L]]
      truth <- as.numeric(test_segments[1L, ])
      naive_pred <- as.numeric(train_segments[nrow(train_segments), ])

      for (method in methods) {
        status <- "ok"
        error_message <- NA_character_
        fit_seconds <- NA_real_
        metrics <- list(nmae = NA_real_, nrmse = NA_real_, smape = NA_real_, mase = NA_real_)
        pred <- NULL

        if (identical(method, "lstm") && !isTRUE(backend$lstm_backend_available)) {
          status <- "skip_backend_unavailable"
        } else if (
          identical(method, "kwf_clustered") &&
          identical(thermosensitivity_status, "ok") &&
          identical(thermosensitive, FALSE)
        ) {
          status <- "skip_not_thermosensitive"
        }

        if (identical(status, "ok")) {
          run <- tryCatch(
            {
              elapsed <- system.time({
                fit <- .elcf4r_benchmark_fit_method(
                  method = method,
                  train_long = train_long,
                  test_long = test_long,
                  train_segments = train_segments,
                  train_covariates = train_covariates,
                  test_covariates = test_covariates,
                  use_temperature = use_temp_window,
                  method_args = method_args,
                  seed = seed
                )
                pred <- .elcf4r_benchmark_predict_method(
                  fit = fit,
                  method = method,
                  test_long = test_long,
                  train_segments = train_segments,
                  train_covariates = train_covariates
                )
              })

              pred <- as.numeric(pred)
              if (length(pred) != length(truth)) {
                stop(
                  "Prediction length mismatch for method `", method,
                  "`: expected ", length(truth), ", got ", length(pred), "."
                )
              }

              list(
                pred = pred,
                fit_seconds = unname(elapsed[["elapsed"]])
              )
            },
            error = function(e) {
              status <<- "error"
              error_message <<- conditionMessage(e)
              NULL
            }
          )

          if (!is.null(run)) {
            pred <- run$pred
            fit_seconds <- run$fit_seconds
            metrics <- elcf4r_metrics(
              truth = truth,
              pred = pred,
              seasonal_period = length(truth),
              naive_pred = naive_pred
            )
          }
        }

        result_rows[[row_id]] <- data.frame(
          benchmark_name = benchmark_name,
          dataset = dataset_label,
          entity_id = id,
          method = method,
          test_date = as.Date(test_date),
          train_start = as.Date(min(train_dates)),
          train_end = as.Date(max(train_dates)),
          train_days = train_days,
          test_points = nrow(test_long),
          use_temperature = use_temp_window,
          thermosensitive = thermosensitive,
          thermosensitivity_status = thermosensitivity_status,
          thermosensitivity_ratio = thermosensitivity_ratio,
          fit_seconds = fit_seconds,
          status = status,
          error_message = error_message,
          nmae = metrics$nmae,
          nrmse = metrics$nrmse,
          smape = metrics$smape,
          mase = metrics$mase,
          stringsAsFactors = FALSE
        )

        if (isTRUE(include_predictions) && identical(status, "ok") && !is.null(pred)) {
          prediction_rows[[row_id]] <- data.frame(
            benchmark_name = benchmark_name,
            dataset = dataset_label,
            entity_id = id,
            method = method,
            test_date = as.Date(test_date),
            time_index = seq_along(truth),
            truth = truth,
            pred = pred,
            naive_pred = naive_pred,
            stringsAsFactors = FALSE
          )
        }

        row_id <- row_id + 1L
      }
    }
  }

  results <- do.call(rbind, result_rows)
  rownames(results) <- NULL
  prediction_rows <- Filter(Negate(is.null), prediction_rows)
  predictions <- if (length(prediction_rows) > 0L) {
    out <- do.call(rbind, prediction_rows)
    rownames(out) <- NULL
    out
  } else {
    data.frame()
  }

  spec <- list(
    benchmark_name = benchmark_name,
    dataset = dataset_label,
    methods = methods,
    entity_ids = eligible_ids,
    cohort_size = length(eligible_ids),
    train_days = train_days,
    test_days = test_days,
    include_predictions = isTRUE(include_predictions),
    use_temperature = isTRUE(use_temperature),
    seed = seed
  )

  structure(
    list(
      results = results,
      predictions = predictions,
      cohort_index = selected_index,
      spec = spec,
      backend = backend
    ),
    class = "elcf4r_benchmark"
  )
}

.elcf4r_benchmark_long_data <- function(panel) {
  keep <- intersect(c("y", "time_index", "dow", "month", "temp"), names(panel))
  panel[, keep, drop = FALSE]
}

.elcf4r_benchmark_has_temperature <- function(train_long, test_long) {
  if (!"temp" %in% names(train_long) || !"temp" %in% names(test_long)) {
    return(FALSE)
  }
  !(all(is.na(train_long[["temp"]])) || all(is.na(test_long[["temp"]])))
}

.elcf4r_benchmark_align_temporal_factors <- function(train_long, test_long) {
  if ("dow" %in% names(train_long) && "dow" %in% names(test_long)) {
    dow_levels <- c(
      "Sunday", "Monday", "Tuesday", "Wednesday",
      "Thursday", "Friday", "Saturday"
    )
    train_long[["dow"]] <- factor(as.character(train_long[["dow"]]), levels = dow_levels)
    test_long[["dow"]] <- factor(as.character(test_long[["dow"]]), levels = dow_levels)
  }
  if ("month" %in% names(train_long) && "month" %in% names(test_long)) {
    month_levels <- sprintf("%02d", seq_len(12L))
    train_long[["month"]] <- factor(as.character(train_long[["month"]]), levels = month_levels)
    test_long[["month"]] <- factor(as.character(test_long[["month"]]), levels = month_levels)
  }

  list(train = train_long, test = test_long)
}

.elcf4r_benchmark_panel_to_segments <- function(panel) {
  seg <- stats::xtabs(y ~ date + time_index, data = panel)
  seg[, order(as.integer(colnames(seg))), drop = FALSE]
}

.elcf4r_benchmark_fit_method <- function(
    method,
    train_long,
    test_long,
    train_segments,
    train_covariates,
    test_covariates,
    use_temperature,
    method_args,
    seed
) {
  overrides <- .elcf4r_benchmark_method_overrides(method_args, method)

  if (identical(method, "gam")) {
    args <- utils::modifyList(
      list(data = train_long, use_temperature = use_temperature),
      overrides
    )
    return(do.call(elcf4r_fit_gam, args))
  }

  if (identical(method, "mars")) {
    args <- utils::modifyList(
      list(data = train_long, use_temperature = use_temperature),
      overrides
    )
    return(do.call(elcf4r_fit_mars, args))
  }

  if (identical(method, "kwf")) {
    args <- utils::modifyList(
      list(
        segments = train_segments,
        covariates = train_covariates,
        target_covariates = test_covariates,
        use_temperature = use_temperature
      ),
      overrides
    )
    return(do.call(elcf4r_fit_kwf, args))
  }

  if (identical(method, "kwf_clustered")) {
    args <- list(
      segments = train_segments,
      covariates = train_covariates,
      target_covariates = test_covariates,
      use_mean_correction = TRUE,
      max_clusters = 10L,
      nstart = 30L
    )
    if (!is.null(seed)) {
      args$cluster_seed <- seed
    }
    args <- utils::modifyList(args, overrides)
    return(do.call(elcf4r_fit_kwf_clustered, args))
  }

  if (identical(method, "lstm")) {
    args <- list(
      segments = train_segments,
      covariates = train_covariates,
      use_temperature = use_temperature,
      lookback_days = 1L,
      units = 8L,
      epochs = 4L,
      batch_size = 4L,
      verbose = 0L
    )
    if (!is.null(seed)) {
      args$seed <- seed
    }
    args <- utils::modifyList(args, overrides)
    return(do.call(elcf4r_fit_lstm, args))
  }

  stop("Unsupported benchmark method `", method, "`.")
}

.elcf4r_benchmark_predict_method <- function(
    fit,
    method,
    test_long,
    train_segments,
    train_covariates
) {
  if (identical(method, "gam") || identical(method, "mars")) {
    return(as.numeric(stats::predict(fit, newdata = test_long)))
  }

  if (identical(method, "lstm")) {
    newdata <- list(
      segments = utils::tail(train_segments, fit$lookback_days),
      covariates = if (is.null(train_covariates)) NULL else utils::tail(train_covariates, fit$lookback_days)
    )
    return(as.numeric(stats::predict(fit, newdata = newdata)))
  }

  as.numeric(stats::predict(fit))
}

.elcf4r_benchmark_method_overrides <- function(method_args, method) {
  if (is.null(method_args) || is.null(method_args[[method]])) {
    return(list())
  }
  method_args[[method]]
}

.elcf4r_benchmark_resolution_label <- function(resolution_minutes) {
  if (isTRUE(all.equal(resolution_minutes, 60))) {
    return("hourly")
  }
  if (isTRUE(all.equal(resolution_minutes, 30))) {
    return("30min")
  }
  if (isTRUE(all.equal(resolution_minutes, round(resolution_minutes)))) {
    return(paste0(as.integer(round(resolution_minutes)), "min"))
  }
  paste0(format(signif(resolution_minutes, 4)), "min")
}

.elcf4r_benchmark_backend_info <- function() {
  out <- list(
    keras3_installed = requireNamespace("keras3", quietly = TRUE),
    tensorflow_installed = requireNamespace("tensorflow", quietly = TRUE),
    reticulate_installed = requireNamespace("reticulate", quietly = TRUE),
    keras3_r_package = NA_character_,
    tensorflow_r_package = NA_character_,
    reticulate_python = NA_character_,
    lstm_backend_available = FALSE
  )

  if (isTRUE(out$keras3_installed)) {
    out$keras3_r_package <- as.character(utils::packageVersion("keras3"))
  }
  if (isTRUE(out$tensorflow_installed)) {
    out$tensorflow_r_package <- as.character(utils::packageVersion("tensorflow"))
  }
  if (isTRUE(out$reticulate_installed) &&
      isTRUE(.elcf4r_reticulate_py_available(initialize = FALSE))) {
    py_config <- tryCatch(.elcf4r_reticulate_py_config(), error = function(e) NULL)
    if (!is.null(py_config) && !is.null(py_config$python)) {
      out$reticulate_python <- py_config$python
    }
  }
  if (exists(".elcf4r_lstm_backend_available", mode = "function")) {
    out$lstm_backend_available <- isTRUE(.elcf4r_lstm_backend_available())
  }

  out
}
