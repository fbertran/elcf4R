#' Download the ELMAS dataset from figshare
#'
#' This function downloads the original ELMAS archive from its public
#' figshare URL and unpacks it to a local directory.
#'
#' @param dest_dir Directory where the files should be unpacked.
#'   Defaults to a temporary directory.
#' @return A character vector with the paths of the extracted files.
#' @export
elcf4r_download_elmas <- function(dest_dir = tempdir()) {
  url <- "https://figshare.com/ndownloader/files/41895786"  # update
  zip_path <- file.path(dest_dir, "elmas.zip")
  utils::download.file(url, destfile = zip_path, mode = "wb")
  utils::unzip(zip_path, exdir = dest_dir)
}

#' Download one or more StoreNet household files from figshare
#'
#' Download one or more StoreNet household files such as `H6_W.csv` into a
#' local directory. The helper uses the figshare article API to resolve the
#' actual file download URL when household-level article IDs are available.
#' Otherwise it falls back to the public StoreNet archive and extracts the
#' requested household files into `dest_dir`.
#'
#' The default mapping currently covers the `H6_W` household file used by the
#' package examples. Additional households can be downloaded either by
#' providing a named `article_ids` vector or by relying on the public archive
#' fallback.
#'
#' @param dest_dir Directory where the downloaded files should be stored.
#' @param ids Character vector of StoreNet household identifiers, for example
#'   `"H6_W"`. Use `NULL` to extract every `H*_W.csv` file from the archive.
#' @param article_ids Optional named integer vector that maps each requested
#'   household identifier to a figshare article ID. When `NULL`, the built-in
#'   mapping is used.
#' @param overwrite Logical; if `TRUE`, existing local files are replaced.
#' @param archive_url Optional figshare archive download URL used when a
#'   requested identifier is not present in the article-ID mapping.
#'
#' @return A character vector with the downloaded local file paths.
#' @export
elcf4r_download_storenet <- function(
    dest_dir = tempdir(),
    ids = "H6_W",
    article_ids = NULL,
    overwrite = FALSE,
    archive_url = "https://figshare.com/ndownloader/files/45123456"
) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package `jsonlite` is required for `elcf4r_download_storenet()`.")
  }

  if (is.null(ids)) {
    ids <- character()
  } else {
    ids <- unique(as.character(ids))
    if (length(ids) < 1L || anyNA(ids) || any(trimws(ids) == "")) {
      stop("`ids` must be NULL or contain non-empty household identifiers.")
    }
  }

  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  article_map <- .elcf4r_storenet_article_map(article_ids = article_ids)
  mapped_ids <- intersect(ids, names(article_map))
  missing_ids <- setdiff(ids, mapped_ids)

  out <- character()
  if (length(mapped_ids) > 0L) {
    out <- c(
      out,
      vapply(
        mapped_ids,
        function(id) {
          .elcf4r_download_storenet_one(
            id = id,
            article_id = article_map[[id]],
            dest_dir = dest_dir,
            overwrite = overwrite
          )
        },
        character(1)
      )
    )
  }

  if (length(missing_ids) > 0L || length(ids) == 0L) {
    if (!nzchar(archive_url)) {
      stop(
        "No StoreNet article ID mapping is available for: ",
        paste(missing_ids, collapse = ", "),
        ", and `archive_url` is empty."
      )
    }
    out <- c(
      out,
      .elcf4r_download_storenet_archive(
        dest_dir = dest_dir,
        ids = missing_ids,
        overwrite = overwrite,
        archive_url = archive_url
      )
    )
  }

  unname(unique(out))
}

.elcf4r_storenet_article_map <- function(article_ids = NULL) {
  default_map <- c(H6_W = 25927201L)

  if (is.null(article_ids)) {
    return(default_map)
  }

  if (is.null(names(article_ids)) || any(names(article_ids) == "")) {
    stop("`article_ids` must be a named integer vector.")
  }

  article_names <- as.character(names(article_ids))
  article_ids <- as.integer(article_ids)
  names(article_ids) <- article_names
  for (nm in article_names) {
    default_map[[nm]] <- article_ids[[nm]]
  }
  default_map
}

.elcf4r_download_storenet_one <- function(id, article_id, dest_dir, overwrite) {
  api_url <- sprintf("https://api.figshare.com/v2/articles/%s/files", article_id)
  files_meta <- jsonlite::fromJSON(api_url, simplifyDataFrame = TRUE)
  file_spec <- .elcf4r_storenet_pick_file(files_meta, id = id)

  dest_path <- file.path(dest_dir, file_spec$file_name)
  if (file.exists(dest_path) && !isTRUE(overwrite)) {
    return(dest_path)
  }

  utils::download.file(file_spec$download_url, destfile = dest_path, mode = "wb")

  if (grepl("\\.zip$", dest_path, ignore.case = TRUE)) {
    extracted <- utils::unzip(dest_path, exdir = dest_dir)
    csv_hits <- extracted[grepl(paste0("^", id, "\\.csv$"), basename(extracted), ignore.case = TRUE)]
    if (length(csv_hits) > 0L) {
      return(csv_hits[[1L]])
    }
    return(extracted[[1L]])
  }

  dest_path
}

.elcf4r_download_storenet_archive <- function(dest_dir, ids, overwrite, archive_url) {
  archive_name <- basename(sub("\\?.*$", "", archive_url))
  if (!grepl("\\.zip$", archive_name, ignore.case = TRUE)) {
    archive_name <- "storenet_archive.zip"
  }
  archive_path <- file.path(dest_dir, archive_name)

  if (!file.exists(archive_path) || isTRUE(overwrite)) {
    utils::download.file(archive_url, destfile = archive_path, mode = "wb")
  }

  extracted <- utils::unzip(archive_path, exdir = dest_dir)
  csv_hits <- extracted[grepl("^H.*_W\\.csv$", basename(extracted), ignore.case = TRUE)]
  if (length(csv_hits) < 1L) {
    stop("The StoreNet archive did not contain any household CSV files.")
  }

  if (length(ids) < 1L) {
    return(csv_hits)
  }

  wanted <- paste0(ids, ".csv")
  keep <- basename(csv_hits) %in% wanted
  if (!all(wanted %in% basename(csv_hits))) {
    missing_ids <- ids[!(wanted %in% basename(csv_hits))]
    stop(
      "The StoreNet archive does not contain: ",
      paste(missing_ids, collapse = ", ")
    )
  }

  unname(csv_hits[keep])
}

.elcf4r_storenet_pick_file <- function(files_meta, id) {
  files_df <- as.data.frame(files_meta, stringsAsFactors = FALSE)
  if (nrow(files_df) < 1L) {
    stop("No files were returned by the figshare API for `", id, "`.")
  }

  file_name_col <- intersect(c("name", "filename"), names(files_df))
  if (length(file_name_col) < 1L || !"download_url" %in% names(files_df)) {
    stop("Unexpected figshare file metadata for `", id, "`.")
  }

  file_name_col <- file_name_col[[1L]]
  target_name <- paste0(id, ".csv")
  exact_match <- trimws(files_df[[file_name_col]]) == target_name
  csv_match <- grepl("\\.csv$", files_df[[file_name_col]], ignore.case = TRUE)

  if (any(exact_match)) {
    row <- files_df[which(exact_match)[[1L]], , drop = FALSE]
  } else if (sum(csv_match) == 1L) {
    row <- files_df[which(csv_match)[[1L]], , drop = FALSE]
  } else {
    stop(
      "Could not identify a unique StoreNet CSV download for `", id,
      "` from the figshare metadata."
    )
  }

  list(
    file_name = as.character(row[[file_name_col]][[1L]]),
    download_url = as.character(row[["download_url"]][[1L]])
  )
}
