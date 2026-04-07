test_that("StoreNet article map merges user-supplied mappings", {
  out <- .elcf4r_storenet_article_map(c(H6_W = 111L, H7_W = 222L))

  expect_equal(out[["H6_W"]], 111L)
  expect_equal(out[["H7_W"]], 222L)
})

test_that("StoreNet metadata picker resolves an exact CSV match", {
  meta <- data.frame(
    name = c("other.csv", "H6_W.csv"),
    download_url = c("https://example.com/other.csv", "https://example.com/H6_W.csv"),
    stringsAsFactors = FALSE
  )

  out <- .elcf4r_storenet_pick_file(meta, id = "H6_W")
  expect_identical(out$file_name, "H6_W.csv")
  expect_identical(out$download_url, "https://example.com/H6_W.csv")
})

test_that("StoreNet archive helper returns requested household files", {
  skip_if_not(capabilities("libcurl"))

  archive_dir <- tempfile("storenet-archive-")
  dest_dir <- tempfile("storenet-dest-")
  dir.create(archive_dir)
  dir.create(dest_dir)
  on.exit(unlink(c(archive_dir, dest_dir), recursive = TRUE, force = TRUE), add = TRUE)
  csv_paths <- file.path(archive_dir, c("H6_W.csv", "H7_W.csv"))
  writeLines("date,Consumption(W)\n2020-01-01 00:00:00,1", csv_paths[[1L]])
  writeLines("date,Consumption(W)\n2020-01-01 00:00:00,2", csv_paths[[2L]])

  archive_path <- file.path(archive_dir, "storenet.zip")
  old_wd <- setwd(archive_dir)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip(zipfile = archive_path, files = basename(csv_paths), flags = "-jq")

  out <- .elcf4r_download_storenet_archive(
    dest_dir = dest_dir,
    ids = "H7_W",
    overwrite = FALSE,
    archive_url = paste0("file://", archive_path)
  )

  expect_length(out, 1L)
  expect_identical(basename(out), "H7_W.csv")
})

test_that("StoreNet archive helper returns all household files when ids is NULL", {
  archive_dir <- tempfile("storenet-archive-")
  dest_dir <- tempfile("storenet-dest-")
  dir.create(archive_dir)
  dir.create(dest_dir)
  on.exit(unlink(c(archive_dir, dest_dir), recursive = TRUE, force = TRUE), add = TRUE)
  csv_paths <- file.path(archive_dir, c("H6_W.csv", "H7_W.csv"))
  writeLines("date,Consumption(W)\n2020-01-01 00:00:00,1", csv_paths[[1L]])
  writeLines("date,Consumption(W)\n2020-01-01 00:00:00,2", csv_paths[[2L]])

  archive_path <- file.path(archive_dir, "storenet.zip")
  old_wd <- setwd(archive_dir)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip(zipfile = archive_path, files = basename(csv_paths), flags = "-jq")

  out <- .elcf4r_download_storenet_archive(
    dest_dir = dest_dir,
    ids = character(),
    overwrite = FALSE,
    archive_url = paste0("file://", archive_path)
  )

  expect_setequal(basename(out), basename(csv_paths))
})

test_that("component validation rejects unsupported IDEAL and GX components", {
  expect_error(
    .elcf4r_validate_components("bad", names(.elcf4r_ideal_component_map())),
    "Unsupported"
  )
  expect_error(
    .elcf4r_validate_components("bad", c("shapefile", "database")),
    "Unsupported"
  )
})

test_that("IDEAL asset map resolves named download links from a local record page", {
  html_path <- tempfile(fileext = ".html")
  writeLines(
    c(
      "<html><body>",
      "<div>00LICENSE.txt</div><a href='https://example.com/00LICENSE.txt'>Download</a>",
      "<div>00README.txt</div><a href='https://example.com/00README.txt'>Download</a>",
      "<div>license_text</div><a href='https://example.com/license_text'>Download</a>",
      "<div>documentation.zip</div><a href='https://example.com/documentation.zip'>Download</a>",
      "<div>auxiliarydata.zip</div><a href='https://example.com/auxiliarydata.zip'>Download</a>",
      "</body></html>"
    ),
    html_path
  )

  out <- .elcf4r_ideal_asset_map(record_url = html_path)

  expect_identical(out[["00LICENSE.txt"]], "https://example.com/00LICENSE.txt")
  expect_identical(out[["documentation.zip"]], "https://example.com/documentation.zip")
  expect_identical(out[["auxiliarydata.zip"]], "https://example.com/auxiliarydata.zip")
})

test_that("IDEAL download helper keeps docs-first assets and respects overwrite", {
  skip_if_not(capabilities("libcurl"))

  source_dir <- tempfile("ideal-source-")
  doc_dir <- tempfile("ideal-doc-")
  aux_dir <- tempfile("ideal-aux-")
  dest_dir <- tempfile("ideal-dest-")
  dir.create(source_dir)
  dir.create(doc_dir)
  dir.create(aux_dir)
  dir.create(dest_dir)
  on.exit(
    unlink(c(source_dir, doc_dir, aux_dir, dest_dir), recursive = TRUE, force = TRUE),
    add = TRUE
  )

  writeLines("license", file.path(source_dir, "00LICENSE.txt"))
  writeLines("remote-readme", file.path(source_dir, "00README.txt"))
  writeLines("license-text", file.path(source_dir, "license_text"))
  writeLines("docs", file.path(doc_dir, "guide.txt"))
  writeLines("aux", file.path(aux_dir, "hourly.csv"))

  doc_zip <- file.path(source_dir, "documentation.zip")
  aux_zip <- file.path(source_dir, "auxiliarydata.zip")
  utils::zip(
    zipfile = doc_zip,
    files = file.path(doc_dir, "guide.txt"),
    flags = "-jq"
  )
  utils::zip(
    zipfile = aux_zip,
    files = file.path(aux_dir, "hourly.csv"),
    flags = "-jq"
  )

  asset_map <- c(
    "00LICENSE.txt" = paste0("file://", file.path(source_dir, "00LICENSE.txt")),
    "00README.txt" = paste0("file://", file.path(source_dir, "00README.txt")),
    "license_text" = paste0("file://", file.path(source_dir, "license_text")),
    "documentation.zip" = paste0("file://", doc_zip),
    "auxiliarydata.zip" = paste0("file://", aux_zip)
  )

  writeLines("local-readme", file.path(dest_dir, "00README.txt"))
  out <- .elcf4r_download_ideal_files(
    dest_dir = dest_dir,
    components = "auxiliary",
    asset_map = asset_map,
    overwrite = FALSE
  )

  expect_setequal(
    basename(out),
    c("00LICENSE.txt", "00README.txt", "license_text", "documentation.zip", "auxiliarydata.zip")
  )
  expect_identical(readLines(file.path(dest_dir, "00README.txt"), warn = FALSE), "local-readme")

  .elcf4r_download_ideal_files(
    dest_dir = dest_dir,
    components = "auxiliary",
    asset_map = asset_map,
    overwrite = TRUE
  )
  expect_identical(readLines(file.path(dest_dir, "00README.txt"), warn = FALSE), "remote-readme")
})

test_that("GX metadata picker resolves shapefile and database assets", {
  meta <- data.frame(
    name = c("GX_whole_database.sqlite", "GX_provincial_shapefile.zip"),
    download_url = c(
      "https://example.com/GX_whole_database.sqlite",
      "https://example.com/GX_provincial_shapefile.zip"
    ),
    stringsAsFactors = FALSE
  )

  shape <- .elcf4r_gx_pick_file(meta, component = "shapefile")
  database <- .elcf4r_gx_pick_file(meta, component = "database")

  expect_identical(shape$file_name, "GX_provincial_shapefile.zip")
  expect_identical(database$file_name, "GX_whole_database.sqlite")
})

test_that("GX download helper extracts zipped assets into the destination directory", {
  skip_if_not(capabilities("libcurl"))

  source_dir <- tempfile("gx-source-")
  payload_dir <- tempfile("gx-payload-")
  dest_dir <- tempfile("gx-dest-")
  dir.create(source_dir)
  dir.create(payload_dir)
  dir.create(dest_dir)
  on.exit(
    unlink(c(source_dir, payload_dir, dest_dir), recursive = TRUE, force = TRUE),
    add = TRUE
  )

  writeLines("shape", file.path(payload_dir, "gx_region.shp"))
  writeLines("dbf", file.path(payload_dir, "gx_region.dbf"))
  zip_path <- file.path(source_dir, "GX_provincial_shapefile.zip")
  utils::zip(
    zipfile = zip_path,
    files = file.path(payload_dir, c("gx_region.shp", "gx_region.dbf")),
    flags = "-jq"
  )

  out <- .elcf4r_download_gx_files(
    dest_dir = dest_dir,
    file_specs = list(list(
      component = "shapefile",
      file_name = basename(zip_path),
      download_url = paste0("file://", zip_path)
    )),
    overwrite = FALSE
  )

  expect_setequal(basename(out), c("gx_region.shp", "gx_region.dbf"))
})
