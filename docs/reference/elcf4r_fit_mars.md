# Fit a MARS model for load curves

Fit a MARS model for load curves

## Usage

``` r
elcf4r_fit_mars(data, use_temperature = FALSE)
```

## Arguments

- data:

  Data frame with columns `y` (load), `time_index` (numeric or factor
  for within day position), `dow`, `month`, optional `temp` and other
  covariates.

- use_temperature:

  Logical. If `TRUE`, include temperature as smooth effect and
  interactions.

## Value

An `elcf4r_model` object with `method = "mars"`.

## Examples

``` r
id1 <- subset(
  elcf4r_iflex_example,
  entity_id == unique(elcf4r_iflex_example$entity_id)[1]
)
train_data <- subset(id1, date < sort(unique(id1$date))[11])
test_data <- subset(id1, date == sort(unique(id1$date))[11])
fit <- elcf4r_fit_mars(train_data[, c("y", "time_index", "dow", "month", "temp")], TRUE)
pred <- predict(fit, newdata = test_data[, c("y", "time_index", "dow", "month", "temp")])
length(pred)
#> [1] 24
```
