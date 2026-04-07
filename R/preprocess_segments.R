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
#'   inferred from the timestamps. Fractional minute values are allowed for
#'   high-frequency data.
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
    resolution_minutes = rep_len(as.numeric(resolution_minutes), n),
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

#' Read and normalize the StoreNet household dataset
#'
#' Read one or more StoreNet-style household CSV files such as `H6_W.csv`,
#' derive the household identifier from the file name, and return a normalized
#' long-format panel.
#'
#' @param path Path to a StoreNet CSV file or to a directory containing files
#'   named like `H6_W.csv`.
#' @param ids Optional vector of household identifiers to keep. Identifiers are
#'   matched against the file stem, for example `"H6_W"`.
#' @param start Optional inclusive lower time bound.
#' @param end Optional inclusive upper time bound.
#' @param tz Time zone used to parse timestamps.
#' @param n_max Optional maximum number of rows to read per file.
#' @param load_col Name of the load column to normalize. Defaults to
#'   `"Consumption(W)"`.
#' @param keep_cols Optional extra source columns to keep. Defaults to the
#'   main battery and production fields when present.
#'
#' @return A normalized data frame with StoreNet household data.
#' @export
elcf4r_read_storenet <- function(
    path = file.path("data-raw", "H6_W.csv"),
    ids = NULL,
    start = NULL,
    end = NULL,
    tz = "UTC",
    n_max = NULL,
    load_col = "Consumption(W)",
    keep_cols = c("Discharge(W)", "Charge(W)", "Production(W)", "State of Charge(%)")
) {
  files <- .elcf4r_resolve_dataset_files(
    path = path,
    pattern = "^H.*_W\\.csv$",
    dataset_label = "StoreNet"
  )
  file_ids <- tools::file_path_sans_ext(basename(files))

  if (!is.null(ids)) {
    ids <- as.character(ids)
    keep_files <- file_ids %in% ids
    files <- files[keep_files]
    file_ids <- file_ids[keep_files]
    if (length(files) == 0L) {
      stop("No StoreNet files matched `ids`.")
    }
  }

  fread_nrows <- if (is.null(n_max)) -1L else as.integer(n_max)
  if (!is.null(n_max) && (!is.finite(n_max) || n_max < 1L)) {
    stop("`n_max` must be NULL or a positive integer.")
  }

  normalized_list <- lapply(
    seq_along(files),
    function(i) {
      dt <- data.table::fread(
        input = files[[i]],
        nrows = fread_nrows,
        showProgress = FALSE
      )
      names(dt) <- trimws(names(dt))
      if (!"date" %in% names(dt)) {
        stop("StoreNet file is missing a `date` column: ", files[[i]])
      }

      trimmed_keep <- intersect(trimws(keep_cols), names(dt))
      trimmed_load <- trimws(load_col)

      dt[["entity_id_source"]] <- file_ids[[i]]
      dt[["source_file"]] <- basename(files[[i]])

      timestamp <- .elcf4r_parse_timestamp(dt[["date"]], tz = tz)
      start_bound <- .elcf4r_parse_time_bound(start, tz = tz)
      end_bound <- .elcf4r_parse_time_bound(end, tz = tz)

      keep_rows <- rep(TRUE, length(timestamp))
      if (!is.null(start_bound)) {
        keep_rows <- keep_rows & timestamp >= start_bound
      }
      if (!is.null(end_bound)) {
        keep_rows <- keep_rows & timestamp <= end_bound
      }
      dt <- dt[keep_rows, ]
      dt[["date"]] <- timestamp[keep_rows]

      normalized <- elcf4r_normalize_panel(
        data = dt,
        id_col = "entity_id_source",
        timestamp_col = "date",
        load_col = trimmed_load,
        dataset = "storenet",
        resolution_minutes = 1L,
        tz = tz,
        keep_cols = c(trimmed_keep, "source_file")
      )

      .elcf4r_rename_columns(
        normalized,
        c(
          "Discharge(W)" = "discharge_w",
          "Charge(W)" = "charge_w",
          "Production(W)" = "production_w",
          "State of Charge(%)" = "state_of_charge_pct"
        )
      )
    }
  )

  normalized <- data.table::rbindlist(normalized_list, use.names = TRUE, fill = TRUE)
  normalized <- as.data.frame(normalized, stringsAsFactors = FALSE)
  ord <- order(normalized[["entity_id"]], normalized[["timestamp"]])
  normalized <- normalized[ord, , drop = FALSE]
  rownames(normalized) <- NULL
  normalized
}

#' Read and normalize the Low Carbon London dataset
#'
#' Read a wide Low Carbon London (LCL) smart-meter file and reshape it into a
#' normalized long-format panel with one row per household timestamp.
#'
#' @param path Path to an LCL CSV file or to a directory containing one.
#' @param ids Optional vector of LCL household identifiers to keep, for example
#'   `"MAC000002"`.
#' @param start Optional inclusive lower time bound.
#' @param end Optional inclusive upper time bound.
#' @param tz Time zone used to parse timestamps.
#' @param n_max Optional maximum number of timestamp rows to read.
#' @param drop_na_load Logical; if `TRUE`, rows with missing load values are
#'   dropped after reshaping.
#'
#' @return A normalized data frame with LCL household data.
#' @export
elcf4r_read_lcl <- function(
    path = file.path("data-raw", "LCL_2013.csv"),
    ids = NULL,
    start = NULL,
    end = NULL,
    tz = "UTC",
    n_max = NULL,
    drop_na_load = TRUE
) {
  csv_path <- .elcf4r_resolve_single_dataset_file(
    path = path,
    pattern = "^LCL.*\\.csv$",
    dataset_label = "LCL"
  )
  fread_nrows <- if (is.null(n_max)) -1L else as.integer(n_max)
  if (!is.null(n_max) && (!is.finite(n_max) || n_max < 1L)) {
    stop("`n_max` must be NULL or a positive integer.")
  }

  select_cols <- "DateTime"
  if (!is.null(ids)) {
    select_cols <- c(select_cols, as.character(ids))
  }

  dt <- data.table::fread(
    input = csv_path,
    select = select_cols,
    nrows = fread_nrows,
    showProgress = FALSE,
    strip.white = TRUE
  )
  names(dt) <- trimws(names(dt))
  if (!"DateTime" %in% names(dt)) {
    stop("LCL file is missing a `DateTime` column.")
  }

  load_cols <- setdiff(names(dt), "DateTime")
  if (length(load_cols) == 0L) {
    stop("No household load columns were selected from the LCL file.")
  }

  dt_long <- data.table::melt(
    data = dt,
    id.vars = "DateTime",
    measure.vars = load_cols,
    variable.name = "entity_id",
    value.name = "y",
    variable.factor = FALSE
  )

  timestamp <- .elcf4r_parse_timestamp(dt_long[["DateTime"]], tz = tz)
  start_bound <- .elcf4r_parse_time_bound(start, tz = tz)
  end_bound <- .elcf4r_parse_time_bound(end, tz = tz)

  keep_rows <- rep(TRUE, length(timestamp))
  if (!is.null(start_bound)) {
    keep_rows <- keep_rows & timestamp >= start_bound
  }
  if (!is.null(end_bound)) {
    keep_rows <- keep_rows & timestamp <= end_bound
  }
  if (isTRUE(drop_na_load)) {
    keep_rows <- keep_rows & !is.na(suppressWarnings(as.numeric(dt_long[["y"]])))
  }

  dt_long <- dt_long[keep_rows, ]
  dt_long[["DateTime"]] <- timestamp[keep_rows]

  normalized <- elcf4r_normalize_panel(
    data = as.data.frame(dt_long, stringsAsFactors = FALSE),
    id_col = "entity_id",
    timestamp_col = "DateTime",
    load_col = "y",
    dataset = "lcl",
    resolution_minutes = 30L,
    tz = tz
  )

  ord <- order(normalized[["entity_id"]], normalized[["timestamp"]])
  normalized <- normalized[ord, , drop = FALSE]
  rownames(normalized) <- NULL
  normalized
}

#' Read and normalize the REFIT cleaned household dataset
#'
#' Read one or more `CLEAN_House*.csv` files from the REFIT dataset, optionally
#' select appliance channels, resample them to a regular time grid, and return a
#' normalized long-format panel.
#'
#' @param path Path to a REFIT file or to a directory containing
#'   `CLEAN_House*.csv` files.
#' @param house_ids Optional vector of house identifiers to keep. These are
#'   matched against file stems such as `"CLEAN_House1"`.
#' @param channels Character vector of load channels to extract. Defaults to
#'   `"Aggregate"`.
#' @param start Optional inclusive lower time bound.
#' @param end Optional inclusive upper time bound.
#' @param tz Time zone used to parse timestamps.
#' @param resolution_minutes Target regular resolution in minutes for the
#'   normalized output. Defaults to `1`.
#' @param agg_fun Aggregation used when resampling to the target grid. One of
#'   `"mean"`, `"sum"` or `"last"`.
#' @param n_max Optional maximum number of raw rows to read per file.
#' @param drop_na_load Logical; if `TRUE`, rows with missing load values are
#'   dropped after resampling.
#'
#' @return A normalized data frame with REFIT household data.
#' @export
elcf4r_read_refit <- function(
    path = "data-raw",
    house_ids = NULL,
    channels = "Aggregate",
    start = NULL,
    end = NULL,
    tz = "UTC",
    resolution_minutes = 1L,
    agg_fun = c("mean", "sum", "last"),
    n_max = NULL,
    drop_na_load = TRUE
) {
  agg_fun <- match.arg(agg_fun)
  files <- .elcf4r_resolve_dataset_files(
    path = path,
    pattern = "^CLEAN_House[0-9]+\\.csv$",
    dataset_label = "REFIT"
  )
  file_ids <- tools::file_path_sans_ext(basename(files))

  if (!is.null(house_ids)) {
    house_ids <- as.character(house_ids)
    keep_files <- file_ids %in% house_ids | sub("^CLEAN_", "", file_ids) %in% house_ids
    files <- files[keep_files]
    file_ids <- file_ids[keep_files]
    if (length(files) == 0L) {
      stop("No REFIT files matched `house_ids`.")
    }
  }

  fread_nrows <- if (is.null(n_max)) -1L else as.integer(n_max)
  if (!is.null(n_max) && (!is.finite(n_max) || n_max < 1L)) {
    stop("`n_max` must be NULL or a positive integer.")
  }

  long_list <- lapply(
    seq_along(files),
    function(i) {
      select_cols <- unique(c("Time", "Unix", "Issues", channels))
      dt <- data.table::fread(
        input = files[[i]],
        select = select_cols,
        nrows = fread_nrows,
        showProgress = FALSE
      )
      names(dt) <- trimws(names(dt))
      missing_channels <- setdiff(channels, names(dt))
      if (length(missing_channels) > 0L) {
        stop(
          "REFIT file ", basename(files[[i]]),
          " is missing channels: ", paste(missing_channels, collapse = ", ")
        )
      }
      for (channel in channels) {
        dt[[channel]] <- as.numeric(dt[[channel]])
      }

      dt_long <- data.table::melt(
        data = dt,
        id.vars = intersect(c("Time", "Unix", "Issues"), names(dt)),
        measure.vars = channels,
        variable.name = "channel",
        value.name = "y",
        variable.factor = FALSE
      )

      timestamp <- .elcf4r_parse_timestamp(dt_long[["Time"]], tz = tz)
      start_bound <- .elcf4r_parse_time_bound(start, tz = tz)
      end_bound <- .elcf4r_parse_time_bound(end, tz = tz)

      keep_rows <- rep(TRUE, length(timestamp))
      if (!is.null(start_bound)) {
        keep_rows <- keep_rows & timestamp >= start_bound
      }
      if (!is.null(end_bound)) {
        keep_rows <- keep_rows & timestamp <= end_bound
      }

      dt_long <- dt_long[keep_rows, ]
      timestamp <- timestamp[keep_rows]

      dt_long[["house_id"]] <- file_ids[[i]]
      if (length(channels) == 1L && identical(channels[[1L]], "Aggregate")) {
        dt_long[["entity_id"]] <- file_ids[[i]]
      } else {
        dt_long[["entity_id"]] <- paste(file_ids[[i]], dt_long[["channel"]], sep = "::")
      }
      dt_long[["bucket_time"]] <- .elcf4r_floor_timestamp(
        timestamp = timestamp,
        resolution_minutes = resolution_minutes,
        tz = tz
      )

      aggregate_value <- .elcf4r_match_agg_fun(agg_fun)
      dt_long <- as.data.frame(dt_long, stringsAsFactors = FALSE)
      group_index <- split(
        seq_len(nrow(dt_long)),
        interaction(
          dt_long[["entity_id"]],
          dt_long[["house_id"]],
          dt_long[["channel"]],
          dt_long[["bucket_time"]],
          drop = TRUE,
          lex.order = TRUE
        )
      )

      resampled <- do.call(
        rbind,
        lapply(
          group_index,
          function(idx) {
            group <- dt_long[idx, , drop = FALSE]
            unix_value <- if ("Unix" %in% names(group)) {
              suppressWarnings(min(as.numeric(group[["Unix"]]), na.rm = TRUE))
            } else {
              NA_real_
            }
            issues_value <- if ("Issues" %in% names(group)) {
              suppressWarnings(max(as.numeric(group[["Issues"]]), na.rm = TRUE))
            } else {
              NA_real_
            }
            data.frame(
              entity_id = group[["entity_id"]][1L],
              house_id = group[["house_id"]][1L],
              channel = group[["channel"]][1L],
              bucket_time = group[["bucket_time"]][1L],
              y = aggregate_value(group[["y"]]),
              unix = unix_value,
              issues = issues_value,
              stringsAsFactors = FALSE
            )
          }
        )
      )

      bad_inf <- !is.finite(resampled[["unix"]])
      if (any(bad_inf)) {
        resampled[["unix"]][bad_inf] <- NA_real_
      }
      bad_inf <- !is.finite(resampled[["issues"]])
      if (any(bad_inf)) {
        resampled[["issues"]][bad_inf] <- NA_real_
      }

      as.data.frame(resampled, stringsAsFactors = FALSE)
    }
  )

  raw_long <- data.table::rbindlist(long_list, use.names = TRUE, fill = TRUE)
  raw_long <- as.data.frame(raw_long, stringsAsFactors = FALSE)
  if (isTRUE(drop_na_load)) {
    raw_long <- raw_long[!is.na(raw_long[["y"]]), , drop = FALSE]
  }

  normalized <- elcf4r_normalize_panel(
    data = raw_long,
    id_col = "entity_id",
    timestamp_col = "bucket_time",
    load_col = "y",
    dataset = "refit",
    resolution_minutes = resolution_minutes,
    tz = tz,
    keep_cols = c("house_id", "channel", "unix", "issues")
  )

  ord <- order(normalized[["entity_id"]], normalized[["timestamp"]])
  normalized <- normalized[ord, , drop = FALSE]
  rownames(normalized) <- NULL
  normalized
}

#' Read and normalize the IDEAL hourly aggregate-electricity scaffold
#'
#' Read a direct IDEAL hourly aggregate-electricity file or search an extracted
#' `auxiliarydata.zip` directory for a matching hourly summary file, then return
#' a normalized long-format panel.
#'
#' @param path Path to an IDEAL hourly summary file or to an extracted IDEAL
#'   auxiliary-data directory.
#' @param ids Optional vector of IDEAL household identifiers to keep.
#' @param start Optional inclusive lower time bound.
#' @param end Optional inclusive upper time bound.
#' @param tz Time zone used to parse timestamps. Defaults to
#'   `"Europe/London"`.
#' @param n_max Optional maximum number of rows to read.
#' @param source IDEAL source flavor. Currently only `"auxiliary_hourly"` is
#'   supported.
#' @param drop_na_load Logical; if `TRUE`, rows with missing load values are
#'   dropped.
#'
#' @return A normalized data frame with IDEAL household data.
#' @export
elcf4r_read_ideal <- function(
    path = "data-raw",
    ids = NULL,
    start = NULL,
    end = NULL,
    tz = "Europe/London",
    n_max = NULL,
    source = "auxiliary_hourly",
    drop_na_load = TRUE
) {
  source <- match.arg(source, choices = c("auxiliary_hourly"))
  csv_path <- .elcf4r_resolve_ideal_path(path = path, source = source)
  fread_nrows <- if (is.null(n_max)) -1L else as.integer(n_max)
  if (!is.null(n_max) && (!is.finite(n_max) || n_max < 1L)) {
    stop("`n_max` must be NULL or a positive integer.")
  }

  dt <- data.table::fread(
    input = csv_path,
    nrows = fread_nrows,
    showProgress = FALSE
  )
  names(dt) <- trimws(names(dt))
  detected <- .elcf4r_detect_ideal_columns(names(dt))

  dt[["home_id"]] <- as.character(dt[[detected$id]])
  if (!is.null(ids)) {
    ids <- as.character(ids)
    dt <- dt[dt[["home_id"]] %in% ids, ]
  }

  timestamp_input <- dt[[detected$timestamp]]
  if (inherits(timestamp_input, "POSIXt")) {
    timestamp_input <- format(timestamp_input, "%Y-%m-%d %H:%M:%OS", tz = "UTC")
  }
  timestamp <- .elcf4r_parse_timestamp(timestamp_input, tz = tz)
  start_bound <- .elcf4r_parse_time_bound(start, tz = tz)
  end_bound <- .elcf4r_parse_time_bound(end, tz = tz)

  keep_rows <- rep(TRUE, length(timestamp))
  if (!is.null(start_bound)) {
    keep_rows <- keep_rows & timestamp >= start_bound
  }
  if (!is.null(end_bound)) {
    keep_rows <- keep_rows & timestamp <= end_bound
  }
  if (isTRUE(drop_na_load)) {
    keep_rows <- keep_rows & !is.na(suppressWarnings(as.numeric(dt[[detected$load]])))
  }

  dt <- dt[keep_rows, ]
  dt[["entity_id_source"]] <- dt[["home_id"]]
  dt[[".ideal_timestamp"]] <- timestamp[keep_rows]
  dt[["source_file"]] <- basename(csv_path)

  normalized <- elcf4r_normalize_panel(
    data = dt,
    id_col = "entity_id_source",
    timestamp_col = ".ideal_timestamp",
    load_col = detected$load,
    dataset = "ideal",
    resolution_minutes = 60L,
    tz = tz,
    keep_cols = c("home_id", "source_file")
  )

  ord <- order(normalized[["entity_id"]], normalized[["timestamp"]])
  normalized <- normalized[ord, , drop = FALSE]
  rownames(normalized) <- NULL
  normalized
}

#' Read and normalize the GX residential transformer-level scaffold
#'
#' Read the GX dataset from either the official SQLite database or a flat export
#' and return a normalized long-format panel. GX is treated as a
#' transformer/community-level dataset rather than an individual-household
#' dataset.
#'
#' @param path Path to a GX SQLite database, a flat export file, or a directory
#'   containing one of them.
#' @param ids Optional vector of GX community/profile identifiers to keep.
#' @param start Optional inclusive lower time bound.
#' @param end Optional inclusive upper time bound.
#' @param tz Time zone used to parse timestamps. Defaults to `"Asia/Shanghai"`.
#' @param n_max Optional maximum number of rows to read.
#' @param drop_na_load Logical; if `TRUE`, rows with missing load values are
#'   dropped.
#'
#' @return A normalized data frame with GX transformer-level data.
#' @export
elcf4r_read_gx <- function(
    path = "data-raw",
    ids = NULL,
    start = NULL,
    end = NULL,
    tz = "Asia/Shanghai",
    n_max = NULL,
    drop_na_load = TRUE
) {
  resolved <- .elcf4r_resolve_gx_path(path)
  fread_nrows <- if (is.null(n_max)) -1L else as.integer(n_max)
  if (!is.null(n_max) && (!is.finite(n_max) || n_max < 1L)) {
    stop("`n_max` must be NULL or a positive integer.")
  }

  source_table <- NA_character_
  if (identical(resolved$type, "sqlite")) {
    con <- DBI::dbConnect(RSQLite::SQLite(), resolved$path)
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    source_table <- .elcf4r_detect_gx_table(con)
    dt <- .elcf4r_read_sqlite_table(con, source_table, n_max = n_max)
  } else {
    dt <- data.table::fread(
      input = resolved$path,
      nrows = fread_nrows,
      showProgress = FALSE
    )
  }

  dt <- as.data.frame(dt, stringsAsFactors = FALSE)
  names(dt) <- trimws(names(dt))
  detected <- .elcf4r_detect_gx_columns(names(dt))

  dt[["community_id"]] <- as.character(dt[[detected$id]])
  if (!is.null(ids)) {
    ids <- as.character(ids)
    dt <- dt[dt[["community_id"]] %in% ids, , drop = FALSE]
  }

  timestamp_input <- dt[[detected$timestamp]]
  if (inherits(timestamp_input, "POSIXt")) {
    timestamp_input <- format(timestamp_input, "%Y-%m-%d %H:%M:%OS", tz = "UTC")
  }
  timestamp <- .elcf4r_parse_timestamp(timestamp_input, tz = tz)
  start_bound <- .elcf4r_parse_time_bound(start, tz = tz)
  end_bound <- .elcf4r_parse_time_bound(end, tz = tz)

  keep_rows <- rep(TRUE, length(timestamp))
  if (!is.null(start_bound)) {
    keep_rows <- keep_rows & timestamp >= start_bound
  }
  if (!is.null(end_bound)) {
    keep_rows <- keep_rows & timestamp <= end_bound
  }
  if (isTRUE(drop_na_load)) {
    keep_rows <- keep_rows & !is.na(suppressWarnings(as.numeric(dt[[detected$load]])))
  }

  dt <- dt[keep_rows, , drop = FALSE]
  dt[["entity_id_source"]] <- dt[["community_id"]]
  dt[[".gx_timestamp"]] <- timestamp[keep_rows]
  dt[["source_file"]] <- basename(resolved$path)
  if (!is.na(source_table)) {
    dt[["source_table"]] <- source_table
  }
  if (!is.null(detected$temp)) {
    dt[["gx_temp"]] <- as.numeric(dt[[detected$temp]])
  }
  if (!is.null(detected$humidity)) {
    dt[["humidity"]] <- dt[[detected$humidity]]
  }
  if (!is.null(detected$holiday)) {
    dt[["holiday"]] <- dt[[detected$holiday]]
  }
  if (!is.null(detected$extreme_weather)) {
    dt[["extreme_weather"]] <- dt[[detected$extreme_weather]]
  }

  keep_cols <- c("community_id", "source_file")
  if ("source_table" %in% names(dt)) {
    keep_cols <- c(keep_cols, "source_table")
  }
  for (optional_col in c("humidity", "holiday", "extreme_weather")) {
    if (optional_col %in% names(dt)) {
      keep_cols <- c(keep_cols, optional_col)
    }
  }

  normalized <- elcf4r_normalize_panel(
    data = dt,
    id_col = "entity_id_source",
    timestamp_col = ".gx_timestamp",
    load_col = detected$load,
    temp_col = if (!is.null(detected$temp)) "gx_temp" else NULL,
    dataset = "gx",
    resolution_minutes = 60L,
    tz = tz,
    keep_cols = keep_cols
  )

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
#'   inferred from timestamps or from a `resolution_minutes` column. Fractional
#'   minute values are allowed.
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
    known_resolution <- unique(stats::na.omit(as.numeric(data[["resolution_minutes"]])))
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
    resolution_minutes = as.numeric(resolution_minutes),
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

.elcf4r_resolve_dataset_files <- function(path, pattern, dataset_label) {
  if (length(path) > 1L) {
    files <- path
  } else if (dir.exists(path)) {
    files <- list.files(path, pattern = pattern, full.names = TRUE)
  } else {
    files <- path
  }

  files <- files[file.exists(files)]
  if (length(files) == 0L) {
    stop("Cannot find ", dataset_label, " data at ", path)
  }

  sort(unique(files))
}

.elcf4r_resolve_single_dataset_file <- function(path, pattern, dataset_label) {
  files <- .elcf4r_resolve_dataset_files(path, pattern, dataset_label)
  if (length(files) > 1L) {
    stop("Expected one ", dataset_label, " file but found ", length(files), ".")
  }
  files[[1L]]
}

.elcf4r_resolve_ideal_path <- function(path, source = "auxiliary_hourly") {
  source <- match.arg(source, choices = c("auxiliary_hourly"))

  if (file.exists(path) && !dir.exists(path)) {
    if (grepl("\\.zip$", path, ignore.case = TRUE)) {
      stop(
        "IDEAL input appears to be a zip archive. Extract `auxiliarydata.zip` ",
        "and point `path` to the extracted directory or hourly file."
      )
    }
    return(path)
  }

  if (!dir.exists(path)) {
    stop("Cannot find IDEAL data at ", path)
  }

  files <- list.files(
    path = path,
    pattern = "\\.(csv|tsv|txt)$",
    full.names = TRUE,
    recursive = TRUE,
    ignore.case = TRUE
  )
  if (length(files) == 0L) {
    stop("Cannot find extracted IDEAL hourly files at ", path)
  }

  scores <- vapply(files, .elcf4r_score_ideal_file, numeric(1))
  if (!any(scores > 0L)) {
    stop(
      "Could not identify an IDEAL aggregate-electricity hourly file under ",
      path,
      ". Checked: ",
      paste(basename(files), collapse = ", ")
    )
  }

  winners <- files[scores == max(scores)]
  if (length(winners) != 1L) {
    stop(
      "Found multiple IDEAL hourly candidates under ",
      path,
      ": ",
      paste(basename(winners), collapse = ", "),
      ". Supply an explicit file path."
    )
  }

  winners[[1L]]
}

.elcf4r_score_ideal_file <- function(path) {
  dt <- tryCatch(
    data.table::fread(input = path, nrows = 50L, showProgress = FALSE),
    error = function(e) NULL
  )
  if (is.null(dt) || ncol(dt) == 0L) {
    return(0)
  }

  detected <- .elcf4r_detect_ideal_columns(names(dt), required = FALSE)
  required <- list(detected$id, detected$timestamp, detected$load)
  if (any(vapply(required, is.null, logical(1)))) {
    return(0)
  }

  file_label <- .elcf4r_normalize_name(basename(path))
  bonus_terms <- c("hour", "hourly", "aux", "auxiliary", "electric", "energy", "load")
  10L + sum(vapply(bonus_terms, function(term) grepl(term, file_label, fixed = TRUE), logical(1)))
}

.elcf4r_detect_ideal_columns <- function(columns, required = TRUE) {
  list(
    id = .elcf4r_match_column_alias(
      columns = columns,
      aliases = c("home_id", "homeid", "house_id", "houseid", "home", "house"),
      label = "IDEAL household identifier",
      required = required
    ),
    timestamp = .elcf4r_match_column_alias(
      columns = columns,
      aliases = c("timestamp", "datetime", "date_time", "date", "time", "localtime", "local_time", "hour"),
      label = "IDEAL timestamp",
      required = required
    ),
    load = .elcf4r_match_column_alias(
      columns = columns,
      aliases = c(
        "aggregate_electricity",
        "aggregate_electricity_kwh",
        "aggregate_electricity_kw",
        "electricity",
        "electricity_kwh",
        "electricity_kw",
        "load",
        "aggregate"
      ),
      label = "IDEAL aggregate electricity",
      required = required
    )
  )
}

.elcf4r_resolve_gx_path <- function(path) {
  if (file.exists(path) && !dir.exists(path)) {
    if (grepl("\\.zip$", path, ignore.case = TRUE)) {
      stop(
        "GX input appears to be a zip archive. Extract the figshare asset and ",
        "point `path` to the SQLite database or flat export."
      )
    }

    if (grepl("\\.(sqlite3?|db)$", path, ignore.case = TRUE)) {
      return(list(path = path, type = "sqlite"))
    }
    if (grepl("\\.(csv|tsv|txt)$", path, ignore.case = TRUE)) {
      return(list(path = path, type = "flat"))
    }

    stop("Unsupported GX input path: ", path)
  }

  if (!dir.exists(path)) {
    stop("Cannot find GX data at ", path)
  }

  sqlite_files <- list.files(
    path = path,
    pattern = "\\.(sqlite3?|db)$",
    full.names = TRUE,
    recursive = TRUE,
    ignore.case = TRUE
  )
  if (length(sqlite_files) > 1L) {
    stop(
      "Found multiple GX database files under ",
      path,
      ": ",
      paste(basename(sqlite_files), collapse = ", "),
      ". Supply an explicit file path."
    )
  }
  if (length(sqlite_files) == 1L) {
    return(list(path = sqlite_files[[1L]], type = "sqlite"))
  }

  flat_files <- list.files(
    path = path,
    pattern = "\\.(csv|tsv|txt)$",
    full.names = TRUE,
    recursive = TRUE,
    ignore.case = TRUE
  )
  if (length(flat_files) == 0L) {
    stop("Cannot find GX database or flat export under ", path)
  }

  scores <- vapply(flat_files, .elcf4r_score_gx_file, numeric(1))
  if (!any(scores > 0L)) {
    stop(
      "Could not identify a GX flat export under ",
      path,
      ". Checked: ",
      paste(basename(flat_files), collapse = ", ")
    )
  }

  winners <- flat_files[scores == max(scores)]
  if (length(winners) != 1L) {
    stop(
      "Found multiple GX flat-file candidates under ",
      path,
      ": ",
      paste(basename(winners), collapse = ", "),
      ". Supply an explicit file path."
    )
  }

  list(path = winners[[1L]], type = "flat")
}

.elcf4r_score_gx_file <- function(path) {
  dt <- tryCatch(
    data.table::fread(input = path, nrows = 50L, showProgress = FALSE),
    error = function(e) NULL
  )
  if (is.null(dt) || ncol(dt) == 0L) {
    return(0)
  }

  detected <- .elcf4r_detect_gx_columns(names(dt), required = FALSE)
  required <- list(detected$id, detected$timestamp, detected$load)
  if (any(vapply(required, is.null, logical(1)))) {
    return(0)
  }

  file_label <- .elcf4r_normalize_name(basename(path))
  bonus_terms <- c("gx", "load", "community", "residential", "database")
  optional_count <- sum(vapply(
    list(detected$temp, detected$humidity, detected$holiday, detected$extreme_weather),
    Negate(is.null),
    logical(1)
  ))

  10L + optional_count + sum(vapply(
    bonus_terms,
    function(term) grepl(term, file_label, fixed = TRUE),
    logical(1)
  ))
}

.elcf4r_detect_gx_table <- function(con) {
  tables <- DBI::dbListTables(con)
  if (length(tables) == 0L) {
    stop("No tables were found in the GX database.")
  }

  scores <- vapply(
    tables,
    function(table_name) {
      dt <- tryCatch(
        .elcf4r_read_sqlite_table(con, table_name, n_max = 50L),
        error = function(e) NULL
      )
      if (is.null(dt) || ncol(dt) == 0L) {
        return(0)
      }

      detected <- .elcf4r_detect_gx_columns(names(dt), required = FALSE)
      required <- list(detected$id, detected$timestamp, detected$load)
      if (any(vapply(required, is.null, logical(1)))) {
        return(0)
      }

      10L + sum(vapply(
        list(detected$temp, detected$humidity, detected$holiday, detected$extreme_weather),
        Negate(is.null),
        logical(1)
      ))
    },
    numeric(1)
  )

  if (!any(scores > 0L)) {
    stop(
      "Could not identify a GX data table. Checked: ",
      paste(tables, collapse = ", ")
    )
  }

  winners <- tables[scores == max(scores)]
  if (length(winners) != 1L) {
    stop(
      "Multiple GX tables match the required schema: ",
      paste(winners, collapse = ", "),
      "."
    )
  }

  winners[[1L]]
}

.elcf4r_read_sqlite_table <- function(con, table_name, n_max = NULL) {
  sql <- paste0(
    "SELECT * FROM ",
    as.character(DBI::dbQuoteIdentifier(con, table_name))
  )
  if (!is.null(n_max)) {
    sql <- paste(sql, "LIMIT", as.integer(n_max))
  }
  DBI::dbGetQuery(con, sql)
}

.elcf4r_detect_gx_columns <- function(columns, required = TRUE) {
  list(
    id = .elcf4r_match_column_alias(
      columns = columns,
      aliases = c(
        "community_id",
        "communityid",
        "community",
        "profile_id",
        "profileid",
        "profile",
        "district_id",
        "districtid",
        "district",
        "transformer_id",
        "transformerid",
        "transformer",
        "area_id",
        "areaid",
        "area"
      ),
      label = "GX community identifier",
      required = required
    ),
    timestamp = .elcf4r_match_column_alias(
      columns = columns,
      aliases = c("timestamp", "datetime", "date_time", "date", "time", "record_time", "recordtime", "hour"),
      label = "GX timestamp",
      required = required
    ),
    load = .elcf4r_match_column_alias(
      columns = columns,
      aliases = c(
        "load",
        "electricity",
        "demand",
        "residential_load",
        "residentialload",
        "total_load",
        "totalload",
        "consumption",
        "consumption_kwh",
        "electricity_kwh",
        "load_kwh"
      ),
      label = "GX load",
      required = required
    ),
    temp = .elcf4r_match_column_alias(
      columns = columns,
      aliases = c("temperature", "temp", "t2m"),
      label = "GX temperature",
      required = FALSE
    ),
    humidity = .elcf4r_match_column_alias(
      columns = columns,
      aliases = c("humidity", "relative_humidity", "relativehumidity", "rh"),
      label = "GX humidity",
      required = FALSE
    ),
    holiday = .elcf4r_match_column_alias(
      columns = columns,
      aliases = c("holiday", "is_holiday", "isholiday"),
      label = "GX holiday",
      required = FALSE
    ),
    extreme_weather = .elcf4r_match_column_alias(
      columns = columns,
      aliases = c(
        "extreme_weather",
        "extremeweather",
        "is_extreme_weather",
        "isextremeweather",
        "extreme_event",
        "extremeevent"
      ),
      label = "GX extreme-weather flag",
      required = FALSE
    )
  )
}

.elcf4r_normalize_name <- function(x) {
  gsub("[^a-z0-9]+", "", tolower(trimws(as.character(x))))
}

.elcf4r_match_column_alias <- function(columns, aliases, label, required = TRUE) {
  normalized_columns <- .elcf4r_normalize_name(columns)

  for (alias in aliases) {
    hits <- which(normalized_columns == .elcf4r_normalize_name(alias))
    if (length(hits) == 1L) {
      return(columns[[hits[[1L]]]])
    }
    if (length(hits) > 1L) {
      stop(
        "Multiple columns matched the ",
        label,
        ": ",
        paste(columns[hits], collapse = ", "),
        "."
      )
    }
  }

  if (!isTRUE(required)) {
    return(NULL)
  }

  stop(
    "Could not identify the ",
    label,
    " column. Available columns are: ",
    paste(columns, collapse = ", "),
    "."
  )
}

.elcf4r_rename_columns <- function(data, rename_map) {
  old_names <- names(rename_map)
  matched <- old_names[old_names %in% names(data)]
  if (length(matched) > 0L) {
    names(data)[match(matched, names(data))] <- unname(rename_map[matched])
  }
  data
}

.elcf4r_floor_timestamp <- function(timestamp, resolution_minutes, tz = "UTC") {
  bucket_seconds <- as.numeric(resolution_minutes) * 60
  if (!is.finite(bucket_seconds) || bucket_seconds <= 0) {
    stop("`resolution_minutes` must be positive.")
  }
  as.POSIXct(
    floor(as.numeric(timestamp) / bucket_seconds) * bucket_seconds,
    origin = "1970-01-01",
    tz = tz
  )
}

.elcf4r_match_agg_fun <- function(agg_fun) {
  switch(
    agg_fun,
    mean = function(x) {
      x <- as.numeric(x)
      x <- x[!is.na(x)]
      if (length(x) == 0L) {
        return(NA_real_)
      }
      mean(x)
    },
    sum = function(x) {
      x <- as.numeric(x)
      x <- x[!is.na(x)]
      if (length(x) == 0L) {
        return(NA_real_)
      }
      sum(x)
    },
    last = function(x) {
      x <- as.numeric(x)
      x <- x[!is.na(x)]
      if (length(x) == 0L) {
        return(NA_real_)
      }
      x[[length(x)]]
    },
    stop("Unknown aggregation function `", agg_fun, "`.")
  )
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
  timestamp_seconds <- sort(unique(as.numeric(timestamp)))
  if (length(timestamp_seconds) < 2L) {
    stop("At least two timestamps are required to infer a resolution.")
  }

  diffs_sec <- round(diff(timestamp_seconds))
  diffs_sec <- diffs_sec[is.finite(diffs_sec) & diffs_sec > 0]
  if (length(diffs_sec) == 0L) {
    stop("Could not infer a positive sampling resolution from timestamps.")
  }

  diff_table <- sort(table(diffs_sec), decreasing = TRUE)
  resolution_seconds <- as.numeric(names(diff_table)[1L])
  resolution_seconds / 60
}

.elcf4r_points_per_day <- function(resolution_minutes) {
  if (is.null(resolution_minutes) || is.na(resolution_minutes) || resolution_minutes <= 0) {
    stop("`resolution_minutes` must be positive.")
  }
  minutes_per_day <- 24 * 60
  points <- minutes_per_day / as.numeric(resolution_minutes)
  if (!isTRUE(all.equal(points, round(points), tolerance = 1e-8))) {
    stop("`resolution_minutes` must divide exactly into 24 hours.")
  }
  as.integer(round(points))
}

.elcf4r_compute_time_index <- function(timestamp, resolution_minutes, tz = "UTC") {
  midnight <- as.POSIXct(as.Date(timestamp, tz = tz), tz = tz)
  seconds_since_midnight <- as.numeric(
    difftime(timestamp, midnight, units = "secs")
  )
  resolution_seconds <- as.numeric(resolution_minutes) * 60
  as.integer(floor((seconds_since_midnight + 1e-8) / resolution_seconds) + 1L)
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
