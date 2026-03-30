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

#' Download the StoreNet Ireland dataset
#'
#' This function downloads the StoreNet electrical load profiles for
#' an energy community in Ireland from the authors repository.
#'
#' @inheritParams elcf4r_download_elmas
#' @return Paths to extracted files.
#' @export
elcf4r_download_storenet <- function(dest_dir = tempdir()) {
  # You can either hard code a stable zip URL or query figshare API.
  # For now, provide a stub so that tests can be skipped.
  stop("Not yet implemented: will be added in a future version.")
}
