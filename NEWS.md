# eclf4R 0.3.0

* Replaced the previous KWF baseline with a wavelet-based implementation using
  `wavelets`, deterministic calendar groups, kernel weighting and
  approximation/detail mean correction.
* Replaced the unused `src/kwf_core.cpp` placeholder with compiled KWF helper
  routines for distances, kernel weights, group restriction and mean-corrected
  forecasts, and wired the R KWF path to those accelerators.
* Added a first-class clustered KWF workflow with thermosensitivity
  classification, wavelet-feature clustering helpers, cluster assignment, and
  a dedicated `elcf4r_fit_kwf_clustered()` model path.
* Generalized dataset ingestion around a common normalized panel schema and
  added dataset adapters for iFlex, StoreNet, Low Carbon London and REFIT.
* Implemented `elcf4r_download_storenet()` with figshare API resolution for
  known household article IDs and an archive fallback for broader StoreNet
  retrieval.
* Added a generic rolling-origin benchmark API through
  `elcf4r_build_benchmark_index()` and `elcf4r_benchmark()`, with saved
  predictions, backend metadata and support for `gam`, `mars`, `kwf`,
  `kwf_clustered` and `lstm`.
* Completed benchmark metric coverage so shipped benchmark artifacts now carry
  populated NMAE, NRMSE, sMAPE and MASE values for all shipped result rows.
* Added shipped example panels and saved benchmark-result datasets for
  StoreNet, Low Carbon London and REFIT, complementing the existing iFlex
  example and benchmark artifacts.
* Expanded the shipped benchmark cohorts to stronger rolling windows: iFlex now
  uses 15 households with 28 train days and 7 test days; the shipped LCL and
  REFIT benchmark cohorts are now filtered to thermosensitive seasonal windows
  so `kwf_clustered` rows are benchmarked rather than skipped.
* Reworked dataset-facing documentation to describe the supported reader
  surface, shipped artifacts and reproducible `data-raw/` rebuild scripts.
* Clarified the dataset roadmap around IDEAL and GX: IDEAL is a future
  candidate dataset with a currently verified CC BY 4.0 source record, while
  GX is treated as a secondary transformer-level benchmark candidate that
  requires explicit licence re-verification before any shipped subset is added.

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
