# Fetch covariates from Copernicus Marine

One
[`datamatch::accessEnvDat()`](https://camilleross.org/datamatch/reference/accessEnvDat.html)
call per dataset entry in `covariates.copernicus`, joined on grid point
and date. This replaces the ~200 lines of hardcoded per-variable raster
paths in `original/load_covars.R`.

## Usage

``` r
fetch_covariates_copernicus(config, years, months)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- years:

  years to fetch

- months:

  months to fetch

## Value

an `sf` POINT object; see
[`fetch_covariates()`](https://camilleross.org/taupatch/reference/fetch_covariates.md)
