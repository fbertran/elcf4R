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
