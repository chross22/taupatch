# Predictor names for a model

Every covariate variable plus configured derived covariates, excluding
the identity, coordinate, and response columns.

## Usage

``` r
predictor_names(dat, config)
```

## Arguments

- dat:

  modeling data, as returned by
  [`attach_covariates()`](https://camilleross.org/taupatch/reference/attach_covariates.md)

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

character vector of predictor column names
