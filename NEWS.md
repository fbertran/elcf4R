# eclf4R 0.2.0

* Added an iFlex preprocessing pipeline with normalized panel readers,
  daily-segment builders, compact shipped example data, and saved benchmark
  result datasets.
* Added package documentation and vignettes for the shipped iFlex workflows
  and benchmark outputs, and documented the bundled `elcf4r_elmas_toy`
  dataset.
* Replaced the placeholder KWF/LSTM paths with working model wrappers,
  unified `predict.elcf4r_model()`, and migrated the LSTM implementation to
  `keras3` with automatic detection of the `r-tensorflow` virtualenv.
* Cleaned up package metadata, namespace declarations, tests, and examples so
  package checks now pass apart from environment-specific CRAN notes.

# eclf4R 0.1.0

* Package creation and initial release containing estimators,
  autoplot helpers, and reliability utilities.
