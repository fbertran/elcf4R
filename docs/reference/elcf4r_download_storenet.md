# Download one or more StoreNet household files from figshare

Download one or more StoreNet household files such as `H6_W.csv` into a
local directory. The helper uses the figshare article API to resolve the
actual file download URL when household-level article IDs are available.
Otherwise it falls back to the public StoreNet archive and extracts the
requested household files into `dest_dir`.

## Usage

``` r
elcf4r_download_storenet(
  dest_dir,
  ids = "H6_W",
  article_ids = NULL,
  overwrite = FALSE,
  archive_url = "https://figshare.com/ndownloader/files/45123456"
)
```

## Arguments

- dest_dir:

  Directory where the downloaded files should be stored.

- ids:

  Character vector of StoreNet household identifiers, for example
  `"H6_W"`. Use `NULL` to extract every `H*_W.csv` file from the
  archive.

- article_ids:

  Optional named integer vector that maps each requested household
  identifier to a figshare article ID. When `NULL`, the built-in mapping
  is used.

- overwrite:

  Logical; if `TRUE`, existing local files are replaced.

- archive_url:

  Optional figshare archive download URL used when a requested
  identifier is not present in the article-ID mapping.

## Value

A character vector with the downloaded local file paths.

## Details

The default mapping currently covers the `H6_W` household file used by
the package examples. Additional households can be downloaded either by
providing a named `article_ids` vector or by relying on the public
archive fallback.
