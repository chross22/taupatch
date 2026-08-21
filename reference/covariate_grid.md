# Build the covariate grid for one month

The prediction surface a fitted model is projected onto: every covariate
grid point for one (year, month), with derived covariates added so the
grid carries the same predictors the model was trained on.

## Usage

``` r
covariate_grid(env_dat, year, month, config)
```

## Arguments

- env_dat:

  covariate data from
  [`fetch_covariates()`](https://camilleross.org/taupatch/reference/fetch_covariates.md)

- year:

  year to extract

- month:

  month to extract

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

a tibble with `lon`, `lat`, and one column per predictor, or `NULL` if
the covariate data has no points for that year and month
