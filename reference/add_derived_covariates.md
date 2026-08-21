# Add derived covariates

Covariates computed from the data rather than fetched. `jday` is
day-of-year, which is how the pooled model represents seasonality — it
is what lets one model, rather than twelve, produce month-specific
projections.

## Usage

``` r
add_derived_covariates(dat, config)
```

## Arguments

- dat:

  a data frame with `year`, `month`, and `day` columns

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

`dat` with the configured derived covariates added
