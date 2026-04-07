# StoreNet benchmark results for shipped forecasting methods

Saved rolling-origin benchmark results for the shipped methods on the
local StoreNet household example. The benchmark is derived from complete
1-minute household days and reports NMAE, NRMSE, sMAPE and MASE for
every shipped row. The clustered KWF variant is only included when the
shipped StoreNet cohort is classified as thermosensitive.

## Format

A data frame with the same benchmark-result schema as
`elcf4r_iflex_benchmark_results`.

## Source

Derived from the local StoreNet raw file with
`data-raw/elcf4r_storenet_artifacts.R`.
