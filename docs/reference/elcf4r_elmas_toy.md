# Toy subset of ELMAS hourly cluster profiles

A compact subset of the public ELMAS dataset containing hourly load
profiles for 3 commercial or industrial load clusters over 70 days. The
object is intended for lightweight examples and tests that demonstrate
time-series or segment-based workflows without shipping the full source
archive.

## Format

A tibble with 5,040 rows and 3 variables:

- time:

  Hourly timestamp.

- cluster_id:

  Cluster identifier, one of 3 retained ELMAS clusters.

- load_mwh:

  Cluster load in MWh.

## Source

Public ELMAS dataset, reduced with package `data-raw` scripts for
examples and tests.
