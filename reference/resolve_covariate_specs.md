# Resolve selected covariate names to Copernicus fetch specifications

Covariates sharing a product and dataset are grouped into one
specification, so selecting SST, SSS, and MLD costs one request rather
than three.

## Usage

``` r
resolve_covariate_specs(selected)
```

## Arguments

- selected:

  covariate names, as in
  [`copernicus_covariates()`](https://camilleross.org/taupatch/reference/copernicus_covariates.md)

## Value

a list of specs with `product_id`, `dataset_id`, `vars`, `depth`, and
`names` (the covariate names each variable maps back to)
