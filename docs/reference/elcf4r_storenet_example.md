# StoreNet example panel for package examples

A compact normalized panel extracted from the local StoreNet household
file `H6_W.csv`. The object contains a small set of complete 1-minute
household days and is intended for examples and lightweight benchmarking
workflows.

## Format

A data frame with normalized panel columns plus StoreNet-specific
fields:

- dataset:

  Dataset label, always `"storenet"`.

- entity_id:

  Household identifier derived from the file name.

- timestamp,date,time_index,y,temp,dow,month,resolution_minutes:

  Common normalized panel fields.

- discharge_w,charge_w,production_w:

  Battery and production fields from the source file in watts.

- state_of_charge_pct:

  Battery state of charge in percent.

- source_file:

  Source CSV file name.

## Source

Public StoreNet raw file `H6_W.csv`, reduced with
`data-raw/elcf4r_storenet_artifacts.R`.
