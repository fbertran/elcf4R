# iFlex example panel for package examples

A compact hourly electricity-demand panel extracted from the public
iFlex dataset. The object contains 14 complete days for each of 3
participants and is intended for examples, tests and lightweight
vignettes.

## Format

A data frame with 1,008 rows and 16 variables:

- dataset:

  Dataset label, always `"iflex"`.

- entity_id:

  Participant identifier.

- timestamp:

  Hourly UTC timestamp.

- date:

  Calendar date of the observation.

- time_index:

  Within-day hourly index from 1 to 24.

- y:

  Hourly electricity demand in kWh.

- temp:

  Outdoor temperature in degrees Celsius.

- dow:

  Day of week.

- month:

  Month as a two-digit factor.

- resolution_minutes:

  Sampling resolution in minutes.

- participation_phase:

  Experiment phase from the source dataset.

- price_signal:

  Experimental price-signal label, when available.

- price_nok_kwh:

  Experimental electricity price in NOK per kWh.

- temp24:

  Lagged 24-hour temperature feature from the source file.

- temp48:

  Lagged 48-hour temperature feature from the source file.

- temp72:

  Lagged 72-hour temperature feature from the source file.

## Source

Public iFlex raw file `data_hourly.csv`, reduced with
`data-raw/elcf4r_iflex_subsets.R`.
