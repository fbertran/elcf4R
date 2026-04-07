# Low Carbon London example panel for package examples

A compact normalized panel extracted from a small group of households in
the Low Carbon London dataset. The object contains complete 30-minute
days and is intended for examples and lightweight benchmarking
workflows.

## Format

A data frame with normalized panel fields:

- dataset:

  Dataset label, always `"lcl"`.

- entity_id:

  Low Carbon London household identifier.

- timestamp,date,time_index,y,temp,dow,month,resolution_minutes:

  Common normalized panel fields.

## Source

Public LCL raw file `LCL_2013.csv`, reduced with
`data-raw/elcf4r_lcl_artifacts.R`.
