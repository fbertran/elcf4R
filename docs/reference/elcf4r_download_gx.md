# Download selected GX dataset components

Download selected assets from the official GX figshare dataset record.
The helper only uses the dataset record itself and does not rely on the
authors' code repository.

## Usage

``` r
elcf4r_download_gx(dest_dir, components = "shapefile", overwrite = FALSE)
```

## Arguments

- dest_dir:

  Directory where the downloaded files should be stored.

- components:

  Character vector of GX components to fetch. Supported values are
  `"shapefile"` and `"database"`.

- overwrite:

  Logical; if `TRUE`, existing local files are replaced.

## Value

A character vector with the downloaded local file paths. Zip assets are
extracted into `dest_dir` and the extracted paths are returned.
