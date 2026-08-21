# Copernicus fetch specifications for a config

Prefers the covariate names in `covariates.selected`, resolved through
[`copernicus_covariates()`](https://camilleross.org/taupatch/reference/copernicus_covariates.md).
A raw `covariates.copernicus` block remains available for datasets the
catalog does not cover.

## Usage

``` r
covariate_specs(config)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

a list of fetch specifications
