# REFIT example panel for package examples

A compact normalized panel extracted from the REFIT cleaned dataset
after resampling to 15-minute resolution. The object contains complete
days for one house and is intended for examples and lightweight
benchmarking workflows.

## Format

A data frame with normalized panel columns plus REFIT-specific fields:

- dataset:

  Dataset label, always `"refit"`.

- entity_id:

  Entity identifier, here the aggregate household channel.

- timestamp,date,time_index,y,temp,dow,month,resolution_minutes:

  Common normalized panel fields.

- house_id:

  REFIT house identifier derived from the file name.

- channel:

  Load channel name, for example `"Aggregate"`.

- unix:

  Minimum Unix timestamp within the resampling bucket.

- issues:

  Maximum issues flag within the resampling bucket.

## Source

Public REFIT cleaned raw files, reduced with
`data-raw/elcf4r_refit_artifacts.R`.
