# Derive deterministic KWF calendar groups

Build the deterministic day groups used by the residential KWF workflow:
weekdays, `pre_holiday`, and `holiday`.

## Usage

``` r
elcf4r_calendar_groups(dates, holidays = NULL)
```

## Arguments

- dates:

  Vector coercible to `Date`.

- holidays:

  Optional vector of holiday dates. If supplied, holiday dates are
  labelled `"holiday"` and the dates immediately before them are
  labelled `"pre_holiday"`.

## Value

An ordered factor with levels `monday`, `tuesday`, `wednesday`,
`thursday`, `friday`, `saturday`, `sunday`, `pre_holiday`, `holiday`.

## Examples

``` r
elcf4r_calendar_groups(
  as.Date(c("2024-12-24", "2024-12-25", "2024-12-26")),
  holidays = as.Date("2024-12-25")
)
#> [1] pre_holiday holiday     thursday   
#> 9 Levels: monday < tuesday < wednesday < thursday < friday < ... < holiday
```
