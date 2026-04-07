#' Download the ELMAS dataset from figshare
#'
#' This function downloads the original ELMAS archive from its public
#' figshare URL and unpacks it to a local directory.
#'
#' @param dest_dir Directory where the files should be unpacked.
#' @return A character vector with the paths of the extracted files.
#' @export
elcf4r_download_elmas <- function(dest_dir) {
  dest_dir <- .elcf4r_require_dest_dir(dest_dir)
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
    dest_dir,
    ids = "H6_W",
    article_ids = NULL,
    overwrite = FALSE,
    archive_url = "https://figshare.com/ndownloader/files/45123456"
) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package `jsonlite` is required for `elcf4r_download_storenet()`.")
  }

  dest_dir <- .elcf4r_require_dest_dir(dest_dir)

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

#' Download selected IDEAL dataset components
#'
#' Download selected assets from the IDEAL Household Energy Dataset record on
#' Edinburgh DataShare. The helper is docs-first: it always retrieves the
#' licence/readme files and `documentation.zip`, while heavy raw-data archives
#' must be requested explicitly through `components`.
#'
#' @param dest_dir Directory where the downloaded files should be stored.
#' @param components Character vector of IDEAL components to fetch. Supported
#'   values are `"documentation"`, `"metadata_and_surveys"`, `"coding"`,
#'   `"auxiliary"`, `"household_sensors"` and
#'   `"room_and_appliance_sensors"`.
#' @param overwrite Logical; if `TRUE`, existing local files are replaced.
#'
#' @return A character vector with the downloaded local file paths.
#' @export
elcf4r_download_ideal <- function(
    dest_dir,
    components = "documentation",
    overwrite = FALSE
) {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    stop("Package `xml2` is required for `elcf4r_download_ideal()`.")
  }
  dest_dir <- .elcf4r_require_dest_dir(dest_dir)

  components <- .elcf4r_validate_components(
    components = components,
    supported = names(.elcf4r_ideal_component_map()),
    arg = "components"
  )
  asset_map <- .elcf4r_ideal_asset_map()
  .elcf4r_download_ideal_files(
    dest_dir = dest_dir,
    components = components,
    asset_map = asset_map,
    overwrite = overwrite
  )
}

#' Download selected GX dataset components
#'
#' Download selected assets from the official GX figshare dataset record. The
#' helper only uses the dataset record itself and does not rely on the authors'
#' code repository.
#'
#' @param dest_dir Directory where the downloaded files should be stored.
#' @param components Character vector of GX components to fetch. Supported
#'   values are `"shapefile"` and `"database"`.
#' @param overwrite Logical; if `TRUE`, existing local files are replaced.
#'
#' @return A character vector with the downloaded local file paths. Zip assets
#'   are extracted into `dest_dir` and the extracted paths are returned.
#' @export
elcf4r_download_gx <- function(
    dest_dir,
    components = "shapefile",
    overwrite = FALSE
) {
  dest_dir <- .elcf4r_require_dest_dir(dest_dir)
  components <- .elcf4r_validate_components(
    components = components,
    supported = c("shapefile", "database"),
    arg = "components"
  )
  files_meta <- .elcf4r_fetch_figshare_files(.elcf4r_gx_article_id())
  file_specs <- lapply(
    components,
    function(component) {
      .elcf4r_gx_pick_file(files_meta = files_meta, component = component)
    }
  )

  .elcf4r_download_gx_files(
    dest_dir = dest_dir,
    file_specs = file_specs,
    overwrite = overwrite
  )
}

.elcf4r_validate_components <- function(components, supported, arg = "components") {
  components <- unique(as.character(components))
  if (length(components) < 1L || anyNA(components) || any(trimws(components) == "")) {
    stop("`", arg, "` must contain at least one non-empty component name.")
  }

  invalid <- setdiff(components, supported)
  if (length(invalid) > 0L) {
    stop(
      "Unsupported `", arg, "` values: ",
      paste(invalid, collapse = ", "),
      ". Supported values are: ",
      paste(supported, collapse = ", "),
      "."
    )
  }

  components
}

.elcf4r_require_dest_dir <- function(dest_dir) {
  if (missing(dest_dir) || is.null(dest_dir)) {
    stop("`dest_dir` must be supplied explicitly.")
  }
  dest_dir <- as.character(dest_dir)
  if (length(dest_dir) != 1L || is.na(dest_dir) || !nzchar(trimws(dest_dir))) {
    stop("`dest_dir` must be a single non-empty path.")
  }
  dest_dir
}

.elcf4r_ideal_component_map <- function() {
  c(
    documentation = "documentation.zip",
    metadata_and_surveys = "metadata_and_surveys.zip",
    coding = "coding.zip",
    auxiliary = "auxiliarydata.zip",
    household_sensors = "household_sensors.zip",
    room_and_appliance_sensors = "room_and_appliance_sensors.zip"
  )
}

.elcf4r_ideal_base_assets <- function() {
  c("00LICENSE.txt", "00README.txt", "license_text", "documentation.zip")
}

.elcf4r_ideal_record_url <- function() {
  "https://datashare.ed.ac.uk/handle/10283/3647?show=full"
}

.elcf4r_ideal_asset_map <- function(record_url = .elcf4r_ideal_record_url()) {
  known_assets <- unique(c(.elcf4r_ideal_base_assets(), unname(.elcf4r_ideal_component_map())))
  doc <- xml2::read_html(record_url)
  nodes <- xml2::xml_find_all(doc, ".//*")
  asset_map <- stats::setNames(rep(NA_character_, length(known_assets)), known_assets)
  current_name <- NULL

  for (node in nodes) {
    node_text <- trimws(xml2::xml_text(node))
    if (node_text %in% known_assets) {
      current_name <- node_text
      next
    }

    if (
      identical(xml2::xml_name(node), "a") &&
      identical(node_text, "Download") &&
      !is.null(current_name)
    ) {
      href <- xml2::xml_attr(node, "href")
      if (!is.na(href) && nzchar(href) && is.na(asset_map[[current_name]])) {
        asset_map[[current_name]] <- xml2::url_absolute(href, record_url)
      }
      current_name <- NULL
    }
  }

  asset_map
}

.elcf4r_download_ideal_files <- function(dest_dir, components, asset_map, overwrite) {
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

  required_assets <- unique(c(
    .elcf4r_ideal_base_assets(),
    unname(.elcf4r_ideal_component_map()[components])
  ))
  missing_assets <- required_assets[
    is.na(asset_map[required_assets]) | !nzchar(asset_map[required_assets])
  ]
  if (length(missing_assets) > 0L) {
    stop(
      "Could not resolve IDEAL download URLs for: ",
      paste(missing_assets, collapse = ", "),
      "."
    )
  }

  out <- vapply(
    required_assets,
    function(asset_name) {
      .elcf4r_download_file(
        url = asset_map[[asset_name]],
        dest_path = file.path(dest_dir, asset_name),
        overwrite = overwrite
      )
    },
    character(1)
  )

  unname(out)
}

.elcf4r_gx_article_id <- function() {
  26333452L
}

.elcf4r_fetch_figshare_files <- function(article_id) {
  api_url <- sprintf("https://api.figshare.com/v2/articles/%s/files", as.integer(article_id))
  jsonlite::fromJSON(api_url, simplifyDataFrame = TRUE)
}

.elcf4r_gx_pick_file <- function(files_meta, component) {
  files_df <- as.data.frame(files_meta, stringsAsFactors = FALSE)
  if (nrow(files_df) < 1L) {
    stop("No files were returned by the GX figshare API.")
  }

  file_name_col <- intersect(c("name", "filename"), names(files_df))
  if (length(file_name_col) < 1L || !"download_url" %in% names(files_df)) {
    stop("Unexpected GX figshare file metadata.")
  }

  file_name_col <- file_name_col[[1L]]
  file_names <- tolower(trimws(files_df[[file_name_col]]))
  score <- integer(length(file_names))

  if (identical(component, "shapefile")) {
    score <- score + 3L * grepl("shape|shapefile", file_names)
    score <- score + 1L * grepl("\\.zip$", file_names)
  } else if (identical(component, "database")) {
    score <- score + 3L * grepl("database", file_names)
    score <- score + 2L * grepl("\\.sqlite3?$|\\.db$", file_names)
    score <- score + 1L * grepl("\\.zip$", file_names)
  } else {
    stop("Unsupported GX component `", component, "`.")
  }

  if (!any(score > 0L)) {
    stop("Could not identify a GX file for component `", component, "`.")
  }

  winner <- which(score == max(score))
  if (length(winner) != 1L) {
    stop(
      "GX component `", component, "` matched multiple files: ",
      paste(files_df[[file_name_col]][winner], collapse = ", "),
      "."
    )
  }

  row <- files_df[winner[[1L]], , drop = FALSE]
  list(
    component = component,
    file_name = as.character(row[[file_name_col]][[1L]]),
    download_url = as.character(row[["download_url"]][[1L]])
  )
}

.elcf4r_download_gx_files <- function(dest_dir, file_specs, overwrite) {
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  out <- unlist(
    lapply(
      file_specs,
      function(spec) {
        dest_path <- .elcf4r_download_file(
          url = spec$download_url,
          dest_path = file.path(dest_dir, spec$file_name),
          overwrite = overwrite
        )
        .elcf4r_extract_if_zip(dest_path = dest_path, exdir = dest_dir)
      }
    ),
    use.names = FALSE
  )

  unname(unique(out))
}

.elcf4r_download_file <- function(url, dest_path, overwrite) {
  if (file.exists(dest_path) && !isTRUE(overwrite)) {
    return(dest_path)
  }

  dir.create(dirname(dest_path), recursive = TRUE, showWarnings = FALSE)
  utils::download.file(url, destfile = dest_path, mode = "wb")
  dest_path
}

.elcf4r_extract_if_zip <- function(dest_path, exdir) {
  if (!grepl("\\.zip$", dest_path, ignore.case = TRUE)) {
    return(dest_path)
  }

  extracted <- utils::unzip(dest_path, exdir = exdir)
  if (length(extracted) < 1L) {
    return(dest_path)
  }
  extracted
}
