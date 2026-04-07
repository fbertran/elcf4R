# iFlex benchmark index of complete participant-days

A compact index of complete days derived from the public iFlex hourly
panel. Each row represents one participant-day with enough metadata to
define deterministic benchmark cohorts without shipping the full raw
panel.

## Format

A data frame with 563,150 rows and 11 variables:

- day_key:

  Unique key built as `entity_id__date`.

- entity_id:

  Participant identifier.

- date:

  Calendar date.

- dow:

  Day of week.

- month:

  Month as a two-digit factor.

- temp_mean:

  Mean daily outdoor temperature in degrees Celsius.

- temp_min:

  Minimum daily outdoor temperature in degrees Celsius.

- temp_max:

  Maximum daily outdoor temperature in degrees Celsius.

- participation_phase:

  Experiment phase from the source dataset.

- price_signal:

  Experimental price-signal label, when available.

- n_points:

  Number of hourly samples retained for the day.

## Source

Public iFlex raw file `data_hourly.csv`, reduced with
`data-raw/elcf4r_iflex_subsets.R`.
