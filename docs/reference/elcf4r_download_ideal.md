# Download selected IDEAL dataset components

Download selected assets from the IDEAL Household Energy Dataset record
on Edinburgh DataShare. The helper is docs-first: it always retrieves
the licence/readme files and `documentation.zip`, while heavy raw-data
archives must be requested explicitly through `components`.

## Usage

``` r
elcf4r_download_ideal(
  dest_dir,
  components = "documentation",
  overwrite = FALSE
)
```

## Arguments

- dest_dir:

  Directory where the downloaded files should be stored.

- components:

  Character vector of IDEAL components to fetch. Supported values are
  `"documentation"`, `"metadata_and_surveys"`, `"coding"`,
  `"auxiliary"`, `"household_sensors"` and
  `"room_and_appliance_sensors"`.

- overwrite:

  Logical; if `TRUE`, existing local files are replaced.

## Value

A character vector with the downloaded local file paths.
