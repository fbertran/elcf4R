#' Select the Python environment used for TensorFlow-backed LSTM fits
#'
#' This helper provides an explicit, user-invoked way to bind the Python
#' environment used by `reticulate` before calling `elcf4r_fit_lstm()`.
#'
#' @param python Optional path to a Python interpreter passed to
#'   `reticulate::use_python()`.
#' @param virtualenv Optional virtualenv name or path passed to
#'   `reticulate::use_virtualenv()`.
#' @param required Logical passed to the corresponding `reticulate` selector.
#'
#' @return Invisibly returns the selected Python interpreter path when it can be
#'   determined.
#' @export
#' @examples
#' if (interactive() &&
#'     requireNamespace("reticulate", quietly = TRUE) &&
#'     reticulate::virtualenv_exists("r-tensorflow")) {
#'   elcf4r_use_tensorflow_env(virtualenv = "r-tensorflow")
#' }
elcf4r_use_tensorflow_env <- function(
    python = NULL,
    virtualenv = NULL,
    required = TRUE
) {
  has_python <- !is.null(python)
  has_virtualenv <- !is.null(virtualenv)

  if (identical(has_python, has_virtualenv)) {
    stop("Supply exactly one of `python` or `virtualenv`.")
  }
  if (!.elcf4r_reticulate_available()) {
    stop(
      "Package `reticulate` is required to configure the Python backend. ",
      "Install `reticulate` or configure Python manually before calling ",
      "`elcf4r_fit_lstm()`."
    )
  }

  required <- as.logical(required)[1L]
  if (is.na(required)) {
    stop("`required` must be TRUE or FALSE.")
  }

  if (has_python) {
    python <- .elcf4r_single_string_arg(python, "python")
    reticulate::use_python(python, required = required)
    return(invisible(normalizePath(path.expand(python), winslash = "/", mustWork = FALSE)))
  }

  virtualenv <- .elcf4r_single_string_arg(virtualenv, "virtualenv")
  reticulate::use_virtualenv(virtualenv, required = required)

  python_path <- tryCatch(
    reticulate::virtualenv_python(virtualenv),
    error = function(e) NA_character_
  )
  if (!is.character(python_path) || length(python_path) != 1L || is.na(python_path)) {
    return(invisible(virtualenv))
  }

  invisible(normalizePath(path.expand(python_path), winslash = "/", mustWork = FALSE))
}

.elcf4r_reticulate_available <- function() {
  requireNamespace("reticulate", quietly = TRUE)
}

.elcf4r_keras3_available <- function() {
  requireNamespace("keras3", quietly = TRUE)
}

.elcf4r_tensorflow_available <- function() {
  requireNamespace("tensorflow", quietly = TRUE)
}

.elcf4r_reticulate_py_available <- function(initialize = FALSE) {
  reticulate::py_available(initialize = initialize)
}

.elcf4r_reticulate_py_config <- function() {
  reticulate::py_config()
}

.elcf4r_single_string_arg <- function(x, arg) {
  x <- as.character(x)
  if (length(x) != 1L || is.na(x) || !nzchar(x)) {
    stop("`", arg, "` must be a single non-empty string.")
  }
  x
}
