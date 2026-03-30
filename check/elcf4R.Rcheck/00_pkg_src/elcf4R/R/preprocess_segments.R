#' Normalize a load panel to the elcf4R schema
#'
#' Convert a raw long-format load table into a normalized panel that uses
#' the column names expected by the package examples and model wrappers.
#'
#' @param data Data frame containing at least an entity identifier, a time
#'   stamp and a load column.
#' @param id_col Name of the entity identifier column.
#' @param timestamp_col Name of the timestamp column.
#' @param load_col Name of the load column.
#' @param temp_col Optional name of the temperature column.
#' @param dataset Short dataset label stored in the normalized output.
#' @param resolution_minutes Sampling resolution in minutes. If `NULL`, it is
#'   inferred from the timestamps.
#' @param tz Time zone used to parse timestamps.
#' @param keep_cols Optional character vector of extra source columns to keep.
#'
#' @return A data frame with normalized columns `dataset`, `entity_id`,
#'   `timestamp`, `date`, `time_index`, `y`, `temp`, `dow`, `month` and
#'   `resolution_minutes`, plus any requested `keep_cols`.
#' @export
elcf4r_normalize_panel <- function(
    data,
    id_col,
    timestamp_col,
    load_col,
    temp_col = NULL,
    dataset = NA_character_,
    resolution_minutes = NULL,
    tz = "UTC",
    keep_cols = NULL
) {
  stopifnot(is.data.frame(data))

  keep_cols <- unique(stats::na.omit(keep_cols))
  required_cols <- c(id_col, timestamp_col, load_col, temp_col, keep_cols)
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0L) {
    stop(
      "Missing required columns: ",
      paste(missing_cols, collapse = ", ")
    )
  }

  timestamp <- .elcf4r_parse_timestamp(data[[timestamp_col]], tz = tz)
  if (is.null(resolution_minutes)) {
    resolution_minutes <- .elcf4r_infer_resolution_minutes(timestamp)
  }

  time_index <- .elcf4r_compute_time_index(
    timestamp = timestamp,
    resolution_minutes = resolution_minutes,
    tz = tz
  )
  calendar <- .elcf4r_calendar_features(timestamp, tz = tz)

  n <- nrow(data)
  out <- data.frame(
    dataset = rep_len(as.character(dataset), n),
    entity_id = as.character(data[[id_col]]),
    timestamp = timestamp,
    date = calendar$date,
    time_index = time_index,
    y = as.numeric(data[[load_col]]),
    temp = if (is.null(temp_col)) rep(NA_real_, n) else as.numeric(data[[temp_col]]),
    dow = calendar$dow,
    month = calendar$month,
    resolution_minutes = rep_len(as.integer(resolution_minutes), n),
    stringsAsFactors = FALSE
  )

  if (length(keep_cols) > 0L) {
    for (col in keep_cols) {
      out[[col]] <- data[[col]]
    }
  }

  out
}

#' Read and normalize the iFlex hourly dataset
#'
#' Read the iFlex hourly consumption table and return a normalized long-format
#' panel ready for feature engineering, segmentation and benchmarking.
#'
#' @param path Path to `data_hourly.csv` or to the directory that contains it.
#' @param ids Optional vector of participant identifiers to keep.
#' @param start Optional inclusive lower time bound.
#' @param end Optional inclusive upper time bound.
#' @param tz Time zone used to parse timestamps. Defaults to `"UTC"` because
#'   the iFlex timestamps are stored with a trailing `Z`.
#' @param n_max Optional maximum number of rows to read. Intended for quick
#'   prototyping on a small subset of the raw file.
#'
#' @return A normalized data frame with load, temperature and calendar fields.
#'   The output also keeps `participation_phase`, `price_signal`,
#'   `price_nok_kwh`, `temp24`, `temp48` and `temp72`.
#' @export
elcf4r_read_iflex <- function(
    path = file.path("data-raw", "iFlex"),
    ids = NULL,
    start = NULL,
    end = NULL,
    tz = "UTC",
    n_max = NULL
) {
  csv_path <- .elcf4r_resolve_iflex_path(path)
  fread_nrows <- if (is.null(n_max)) -1L else as.integer(n_max)
  if (!is.null(n_max) && (!is.finite(n_max) || n_max < 1L)) {
    stop("`n_max` must be NULL or a positive integer.")
  }

  select_cols <- c(
    "ID",
    "From",
    "Participation_Phase",
    "Demand_kWh",
    "Price_signal",
    "Experiment_price_NOK_kWh",
    "Temperature",
    "Temperature24",
    "Temperature48",
    "Temperature72"
  )

  dt <- data.table::fread(
    input = csv_path,
    select = select_cols,
    nrows = fread_nrows,
    showProgress = FALSE
  )

  if (!is.null(ids)) {
    ids <- as.character(ids)
    dt <- dt[dt[["ID"]] %in% ids, ]
  }

  timestamp <- .elcf4r_parse_timestamp(dt[["From"]], tz = tz)
  start_bound <- .elcf4r_parse_time_bound(start, tz = tz)
  end_bound <- .elcf4r_parse_time_bound(end, tz = tz)

  if (!is.null(start_bound)) {
    dt <- dt[timestamp >= start_bound, ]
    timestamp <- timestamp[timestamp >= start_bound]
  }
  if (!is.null(end_bound)) {
    dt <- dt[timestamp <= end_bound, ]
    timestamp <- timestamp[timestamp <= end_bound]
  }

  dt[["From"]] <- timestamp
  normalized <- elcf4r_normalize_panel(
    data = dt,
    id_col = "ID",
    timestamp_col = "From",
    load_col = "Demand_kWh",
    temp_col = "Temperature",
    dataset = "iflex",
    resolution_minutes = 60L,
    tz = tz,
    keep_cols = c(
      "Participation_Phase",
      "Price_signal",
      "Experiment_price_NOK_kWh",
      "Temperature24",
      "Temperature48",
      "Temperature72"
    )
  )

  names(normalized)[names(normalized) == "Participation_Phase"] <- "participation_phase"
  names(normalized)[names(normalized) == "Price_signal"] <- "price_signal"
  names(normalized)[names(normalized) == "Experiment_price_NOK_kWh"] <- "price_nok_kwh"
  names(normalized)[names(normalized) == "Temperature24"] <- "temp24"
  names(normalized)[names(normalized) == "Temperature48"] <- "temp48"
  names(normalized)[names(normalized) == "Temperature72"] <- "temp72"

  if ("price_signal" %in% names(normalized)) {
    blank_signal <- trimws(as.character(normalized[["price_signal"]])) == ""
    normalized[["price_signal"]][blank_signal] <- NA_character_
  }

  ord <- order(normalized[["entity_id"]], normalized[["timestamp"]])
  normalized <- normalized[ord, , drop = FALSE]
  rownames(normalized) <- NULL
  normalized
}

#' Build daily load-curve segments from a normalized panel
#'
#' Convert a long-format load table into one row per entity-day and one column
#' per within-day time index. This is the matrix representation required by
#' functional load-curve models and rolling benchmark scripts.
#'
#' @param data Data frame containing at least entity id, timestamp and load.
#' @param id_col Name of the entity identifier column.
#' @param timestamp_col Name of the timestamp column.
#' @param value_col Name of the load column.
#' @param temp_col Optional name of a temperature column used to derive day
#'   summaries.
#' @param carry_cols Optional day-level columns to propagate into the returned
#'   covariate table. Their first non-missing value within each day is kept.
#' @param expected_points_per_day Expected number of samples per day. If `NULL`,
#'   it is derived from `resolution_minutes`.
#' @param resolution_minutes Sampling resolution in minutes. If `NULL`, it is
#'   inferred from timestamps or from a `resolution_minutes` column.
#' @param complete_days_only If `TRUE`, incomplete or duplicated days are
#'   dropped from the output.
#' @param drop_na_value If `TRUE`, days with missing load values are dropped.
#' @param tz Time zone used to derive dates and within-day positions.
#'
#' @return A list with components `segments`, `covariates`, `resolution_minutes`
#'   and `points_per_day`.
#' @export
#' @examples
#' id1 <- subset(
#'   elcf4r_iflex_example,
#'   entity_id == unique(elcf4r_iflex_example$entity_id)[1]
#' )
#' daily <- elcf4r_build_daily_segments(id1, carry_cols = "participation_phase")
#' dim(daily$segments)
#' names(daily$covariates)
elcf4r_build_daily_segments <- function(
    data,
    id_col = "entity_id",
    timestamp_col = "timestamp",
    value_col = "y",
    temp_col = "temp",
    carry_cols = NULL,
    expected_points_per_day = NULL,
    resolution_minutes = NULL,
    complete_days_only = TRUE,
    drop_na_value = TRUE,
    tz = "UTC"
) {
  stopifnot(is.data.frame(data))

  required_cols <- c(id_col, timestamp_col, value_col)
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0L) {
    stop(
      "Missing required columns: ",
      paste(missing_cols, collapse = ", ")
    )
  }

  if (length(carry_cols) > 0L) {
    missing_carry <- setdiff(carry_cols, names(data))
    if (length(missing_carry) > 0L) {
      stop(
        "Unknown carry columns: ",
        paste(missing_carry, collapse = ", ")
      )
    }
  }

  timestamp <- .elcf4r_parse_timestamp(data[[timestamp_col]], tz = tz)
  if (is.null(resolution_minutes) && "resolution_minutes" %in% names(data)) {
    known_resolution <- unique(stats::na.omit(as.integer(data[["resolution_minutes"]])))
    if (length(known_resolution) > 0L) {
      resolution_minutes <- known_resolution[1L]
    }
  }
  if (is.null(resolution_minutes)) {
    resolution_minutes <- .elcf4r_infer_resolution_minutes(timestamp)
  }
  if (is.null(expected_points_per_day)) {
    expected_points_per_day <- .elcf4r_points_per_day(resolution_minutes)
  }

  dt <- data.table::as.data.table(data)
  dt[[".timestamp"]] <- timestamp
  if (!"date" %in% names(dt)) {
    dt[["date"]] <- as.Date(timestamp, tz = tz)
  }
  if (!"time_index" %in% names(dt)) {
    dt[["time_index"]] <- .elcf4r_compute_time_index(
      timestamp = timestamp,
      resolution_minutes = resolution_minutes,
      tz = tz
    )
  }

  dt[["day_key"]] <- paste(dt[[id_col]], dt[["date"]], sep = "__")
  ord <- order(dt[[id_col]], dt[["date"]], dt[["time_index"]], dt[[".timestamp"]])
  dt <- dt[ord, ]

  summary_cols <- c("day_key", id_col, "date")
  dt_df <- as.data.frame(dt, stringsAsFactors = FALSE)
  day_key_levels <- unique(dt_df[["day_key"]])
  day_groups <- split(
    seq_len(nrow(dt_df)),
    factor(dt_df[["day_key"]], levels = day_key_levels)
  )

  day_summary <- do.call(
    rbind,
    lapply(
      day_groups,
      function(idx) {
        day_data <- dt_df[idx, , drop = FALSE]
        row <- list(
          day_key = day_data[["day_key"]][1L],
          date = day_data[["date"]][1L],
          n_points = nrow(day_data),
          n_unique_index = length(unique(day_data[["time_index"]])),
          has_duplicate_index = length(unique(day_data[["time_index"]])) != nrow(day_data),
          has_missing_value = any(is.na(day_data[[value_col]])),
          dow = if ("dow" %in% names(day_data)) {
            .elcf4r_reduce_day_value(as.character(day_data[["dow"]]))
          } else {
            NA_character_
          },
          month = if ("month" %in% names(day_data)) {
            .elcf4r_reduce_day_value(as.character(day_data[["month"]]))
          } else {
            NA_character_
          },
          temp_mean = if (!is.null(temp_col) && temp_col %in% names(day_data)) {
            .elcf4r_safe_numeric_stat(day_data[[temp_col]], "mean")
          } else {
            NA_real_
          },
          temp_min = if (!is.null(temp_col) && temp_col %in% names(day_data)) {
            .elcf4r_safe_numeric_stat(day_data[[temp_col]], "min")
          } else {
            NA_real_
          },
          temp_max = if (!is.null(temp_col) && temp_col %in% names(day_data)) {
            .elcf4r_safe_numeric_stat(day_data[[temp_col]], "max")
          } else {
            NA_real_
          }
        )
        row[[id_col]] <- day_data[[id_col]][1L]
        if (length(carry_cols) > 0L) {
          for (col in carry_cols) {
            row[[col]] <- .elcf4r_reduce_day_value(day_data[[col]])
          }
        }
        row <- row[c(summary_cols, setdiff(names(row), summary_cols))]
        as.data.frame(row, stringsAsFactors = FALSE)
      }
    )
  )
  rownames(day_summary) <- NULL

  keep <- !day_summary[["has_duplicate_index"]]
  if (isTRUE(complete_days_only)) {
    keep <- keep & day_summary[["n_unique_index"]] == expected_points_per_day
  }
  if (isTRUE(drop_na_value)) {
    keep <- keep & !day_summary[["has_missing_value"]]
  }

  day_summary <- day_summary[keep, ]
  if (nrow(day_summary) == 0L) {
    stop("No valid day segments remain after filtering.")
  }

  dt_keep <- dt[dt[["day_key"]] %in% day_summary[["day_key"]], ]
  wide_formula <- stats::as.formula(
    paste("day_key +", id_col, "+ date ~ time_index")
  )
  wide <- data.table::dcast(
    data = dt_keep,
    formula = wide_formula,
    value.var = value_col
  )

  segment_cols <- setdiff(names(wide), c("day_key", id_col, "date"))
  segment_order <- order(as.integer(segment_cols))
  segment_cols <- segment_cols[segment_order]
  segments <- as.matrix(wide[, segment_cols, with = FALSE])
  storage.mode(segments) <- "double"
  rownames(segments) <- wide[["day_key"]]

  covariates <- day_summary[match(wide[["day_key"]], day_summary[["day_key"]]), ]
  rownames(covariates) <- covariates[["day_key"]]

  list(
    segments = segments,
    covariates = covariates,
    resolution_minutes = as.integer(resolution_minutes),
    points_per_day = as.integer(expected_points_per_day)
  )
}

.elcf4r_resolve_iflex_path <- function(path) {
  if (dir.exists(path)) {
    path <- file.path(path, "data_hourly.csv")
  }
  if (!file.exists(path)) {
    stop("Cannot find iFlex hourly data at ", path)
  }
  path
}

.elcf4r_parse_time_bound <- function(x, tz = "UTC") {
  if (is.null(x)) {
    return(NULL)
  }
  .elcf4r_parse_timestamp(x, tz = tz)
}

.elcf4r_parse_timestamp <- function(x, tz = "UTC") {
  if (inherits(x, "POSIXt")) {
    return(as.POSIXct(x, tz = tz))
  }
  if (inherits(x, "Date")) {
    return(as.POSIXct(x, tz = tz))
  }

  x <- trimws(as.character(x))
  ts <- suppressWarnings(
    as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%OSZ", tz = tz)
  )
  missing_ts <- is.na(ts)
  if (any(missing_ts)) {
    ts[missing_ts] <- suppressWarnings(
      as.POSIXct(x[missing_ts], format = "%Y-%m-%d %H:%M:%OS", tz = tz)
    )
  }
  missing_ts <- is.na(ts)
  if (any(missing_ts)) {
    ts[missing_ts] <- suppressWarnings(as.POSIXct(x[missing_ts], tz = tz))
  }
  if (anyNA(ts)) {
    stop("Could not parse all timestamps.")
  }
  ts
}

.elcf4r_infer_resolution_minutes <- function(timestamp) {
  timestamp <- sort(unique(as.numeric(timestamp)))
  if (length(timestamp) < 2L) {
    stop("At least two timestamps are required to infer a resolution.")
  }

  diffs_min <- diff(timestamp) / 60
  diffs_min <- diffs_min[is.finite(diffs_min) & diffs_min > 0]
  if (length(diffs_min) == 0L) {
    stop("Could not infer a positive sampling resolution from timestamps.")
  }

  resolution_minutes <- min(diffs_min)
  rounded <- round(resolution_minutes)
  if (!isTRUE(all.equal(resolution_minutes, rounded))) {
    stop("Sampling resolution is not an integer number of minutes.")
  }

  as.integer(rounded)
}

.elcf4r_points_per_day <- function(resolution_minutes) {
  if (is.null(resolution_minutes) || is.na(resolution_minutes) || resolution_minutes <= 0L) {
    stop("`resolution_minutes` must be a positive integer.")
  }
  minutes_per_day <- 24L * 60L
  if (minutes_per_day %% resolution_minutes != 0L) {
    stop("`resolution_minutes` must divide exactly into 24 hours.")
  }
  as.integer(minutes_per_day / resolution_minutes)
}

.elcf4r_compute_time_index <- function(timestamp, resolution_minutes, tz = "UTC") {
  midnight <- as.POSIXct(as.Date(timestamp, tz = tz), tz = tz)
  minutes_since_midnight <- as.integer(
    difftime(timestamp, midnight, units = "mins")
  )
  as.integer(floor(minutes_since_midnight / resolution_minutes) + 1L)
}

.elcf4r_calendar_features <- function(timestamp, tz = "UTC") {
  posix_lt <- as.POSIXlt(timestamp, tz = tz)
  dow_labels <- c(
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday"
  )
  dow <- factor(dow_labels[posix_lt$wday + 1L], levels = dow_labels)
  month <- factor(
    sprintf("%02d", posix_lt$mon + 1L),
    levels = sprintf("%02d", seq_len(12L))
  )

  list(
    date = as.Date(timestamp, tz = tz),
    dow = dow,
    month = month
  )
}

.elcf4r_reduce_day_value <- function(x) {
  original <- x
  if (is.factor(x)) {
    x <- as.character(x)
  }
  valid <- !is.na(x)
  if (is.character(x)) {
    valid <- valid & nzchar(trimws(x))
  }
  x <- x[valid]
  if (length(x) == 0L) {
    return(.elcf4r_missing_like(original))
  }
  x[[1L]]
}

.elcf4r_safe_numeric_stat <- function(x, stat) {
  x <- as.numeric(x)
  x <- x[!is.na(x)]
  if (length(x) == 0L) {
    return(NA_real_)
  }

  switch(
    stat,
    mean = mean(x),
    min = min(x),
    max = max(x),
    stop("Unknown statistic `", stat, "`."),
    USE.NAMES = FALSE
  )
}

.elcf4r_missing_like <- function(x) {
  if (inherits(x, "POSIXct")) {
    return(as.POSIXct(NA))
  }
  if (inherits(x, "Date")) {
    return(as.Date(NA))
  }
  if (is.character(x) || is.factor(x)) {
    return(NA_character_)
  }
  if (is.integer(x)) {
    return(NA_integer_)
  }
  if (is.numeric(x)) {
    return(NA_real_)
  }
  if (is.logical(x)) {
    return(NA)
  }
  NA_character_
}
