# Build a shipped benchmark-results dataset for iFlex.
#
# This script is not run on CRAN. Execute it manually from the package root
# after `data-raw/elcf4r_iflex_subsets.R` has created
# `data/elcf4r_iflex_benchmark_index.rda`.

if (!requireNamespace("usethis", quietly = TRUE)) {
  stop("Package `usethis` is required to save package datasets.")
}

preprocess_env <- new.env(parent = globalenv())
sys.source(file.path("R", "preprocess_segments.R"), envir = preprocess_env)
sys.source(file.path("R", "elcf4r_fit_gam.R"), envir = preprocess_env)
sys.source(file.path("R", "elcf4r_fit_mars.R"), envir = preprocess_env)
sys.source(file.path("R", "elcf4r_fit_kwf.R"), envir = preprocess_env)
sys.source(file.path("R", "elcf4r_fit_lstm.R"), envir = preprocess_env)
sys.source(file.path("R", "model_predict.R"), envir = preprocess_env)
sys.source(file.path("R", "metrics.R"), envir = preprocess_env)

elcf4r_read_iflex <- get("elcf4r_read_iflex", envir = preprocess_env)
elcf4r_fit_gam <- get("elcf4r_fit_gam", envir = preprocess_env)
elcf4r_fit_mars <- get("elcf4r_fit_mars", envir = preprocess_env)
elcf4r_fit_kwf <- get("elcf4r_fit_kwf", envir = preprocess_env)
elcf4r_fit_lstm <- get("elcf4r_fit_lstm", envir = preprocess_env)
elcf4r_metrics <- get("elcf4r_metrics", envir = preprocess_env)
lstm_backend_available <- get(".elcf4r_lstm_backend_available", envir = preprocess_env)
predict_elcf4r_model <- get("predict.elcf4r_model", envir = preprocess_env)

benchmark_index_path <- file.path("data", "elcf4r_iflex_benchmark_index.rda")
if (!file.exists(benchmark_index_path)) {
  stop(
    "Cannot find ", benchmark_index_path,
    ". Run data-raw/elcf4r_iflex_subsets.R first."
  )
}

load(benchmark_index_path)

cohort_size <- 10L
train_days <- 28L
test_days <- 5L
required_days <- train_days + test_days

benchmark_methods <- c("gam", "mars", "kwf")
if (isTRUE(lstm_backend_available())) {
  benchmark_methods <- c(benchmark_methods, "lstm")
}
benchmark_name <- paste0(
  "iflex_hourly_",
  cohort_size,
  "_ids_",
  train_days,
  "_train_",
  test_days,
  "_test_",
  length(benchmark_methods),
  "_methods"
)

days_per_id <- table(elcf4r_iflex_benchmark_index$entity_id)
eligible_ids <- sort(names(days_per_id[days_per_id >= required_days]))
benchmark_ids <- head(eligible_ids, cohort_size)

selected_index <- do.call(
  rbind,
  lapply(
    benchmark_ids,
    function(id) {
      head(
        elcf4r_iflex_benchmark_index[
          elcf4r_iflex_benchmark_index$entity_id == id,
        ],
        required_days
      )
    }
  )
)
rownames(selected_index) <- NULL

selected_day_keys <- selected_index$day_key
iflex_panel <- elcf4r_read_iflex(
  path = file.path("data-raw", "iFlex"),
  ids = benchmark_ids
)
iflex_panel <- iflex_panel[
  paste(iflex_panel$entity_id, iflex_panel$date, sep = "__") %in% selected_day_keys,
]
iflex_panel <- iflex_panel[order(iflex_panel$entity_id, iflex_panel$timestamp), ]
rownames(iflex_panel) <- NULL

benchmark_rows <- vector("list", length = length(benchmark_ids) * test_days * length(benchmark_methods))
row_id <- 1L

.panel_to_segments <- function(panel) {
  seg <- xtabs(y ~ date + time_index, data = panel)
  seg <- seg[, order(as.integer(colnames(seg))), drop = FALSE]
  seg
}

for (id in benchmark_ids) {
  id_index <- selected_index[selected_index$entity_id == id, , drop = FALSE]
  id_days <- id_index$date
  id_panel <- iflex_panel[iflex_panel$entity_id == id, , drop = FALSE]

  for (test_offset in seq_len(test_days)) {
    test_pos <- train_days + test_offset
    train_dates <- id_days[(test_pos - train_days):(test_pos - 1L)]
    test_date <- id_days[test_pos]

    train_data <- id_panel[
      id_panel$date %in% train_dates,
      c("y", "time_index", "dow", "month", "temp"),
      drop = FALSE
    ]
    test_data <- id_panel[
      id_panel$date == test_date,
      c("y", "time_index", "dow", "month", "temp"),
      drop = FALSE
    ]
    train_segment_panel <- id_panel[id_panel$date %in% train_dates, , drop = FALSE]
    test_segment_panel <- id_panel[id_panel$date == test_date, , drop = FALSE]
    train_segments <- .panel_to_segments(train_segment_panel)
    test_segments <- .panel_to_segments(test_segment_panel)
    train_covariates <- id_index[id_index$date %in% train_dates, , drop = FALSE]
    train_covariates <- train_covariates[match(as.Date(rownames(train_segments)), train_covariates$date), , drop = FALSE]
    test_covariates <- id_index[id_index$date == test_date, , drop = FALSE]

    method_specs <- list(
      gam = list(
        fit = function() elcf4r_fit_gam(train_data, use_temperature = TRUE),
        predict = function(fit) predict_elcf4r_model(fit, newdata = test_data)
      ),
      mars = list(
        fit = function() elcf4r_fit_mars(train_data, use_temperature = TRUE),
        predict = function(fit) predict_elcf4r_model(fit, newdata = test_data)
      ),
      kwf = list(
        fit = function() elcf4r_fit_kwf(
          segments = train_segments,
          covariates = train_covariates,
          target_covariates = test_covariates,
          use_temperature = TRUE
        ),
        predict = function(fit) predict_elcf4r_model(fit)
      ),
      lstm = list(
        fit = function() elcf4r_fit_lstm(
          segments = train_segments,
          covariates = train_covariates,
          use_temperature = TRUE,
          lookback_days = 1L,
          units = 8L,
          epochs = 4L,
          batch_size = 4L,
          verbose = 0L
        ),
        predict = function(fit) predict_elcf4r_model(fit)
      )
    )
    method_specs <- method_specs[benchmark_methods]

    for (method in names(method_specs)) {
      fit_seconds <- NA_real_
      status <- "ok"
      error_message <- NA_character_
      metrics <- list(nmae = NA_real_, nrmse = NA_real_, smape = NA_real_, mase = NA_real_)

      result <- tryCatch(
        {
          elapsed <- system.time({
            fit <- method_specs[[method]]$fit()
            pred <- as.numeric(method_specs[[method]]$predict(fit))
          })
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

      if (!is.null(result)) {
        fit_seconds <- result$fit_seconds
        metrics <- elcf4r_metrics(as.numeric(test_segments[1, ]), result$pred)
      }

      benchmark_rows[[row_id]] <- data.frame(
        benchmark_name = benchmark_name,
        dataset = "iflex",
        entity_id = id,
        method = method,
        test_date = as.Date(test_date),
        train_start = as.Date(min(train_dates)),
        train_end = as.Date(max(train_dates)),
        train_days = train_days,
        test_points = nrow(test_data),
        use_temperature = TRUE,
        fit_seconds = fit_seconds,
        status = status,
        error_message = error_message,
        nmae = metrics$nmae,
        nrmse = metrics$nrmse,
        smape = metrics$smape,
        mase = metrics$mase,
        stringsAsFactors = FALSE
      )
      row_id <- row_id + 1L
    }
  }
}

elcf4r_iflex_benchmark_results <- do.call(rbind, benchmark_rows)
rownames(elcf4r_iflex_benchmark_results) <- NULL

usethis::use_data(
  elcf4r_iflex_benchmark_results,
  compress = "xz",
  overwrite = TRUE
)
