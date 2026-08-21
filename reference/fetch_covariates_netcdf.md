# Read covariates from a directory of NetCDF files

For when the covariate files are already on disk rather than being
fetched.

## Usage

``` r
fetch_covariates_netcdf(config, years, months)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- years:

  years to keep

- months:

  months to keep

## Value

an `sf` POINT object; see
[`fetch_covariates()`](https://camilleross.org/taupatch/reference/fetch_covariates.md)
