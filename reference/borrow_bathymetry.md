# Temporarily attach the bathymetry columns derivoce steps read

Bathymetry reaches stations and the projection grid on its own, both
after this point, so a step reading a depth column has to be given one
here.

## Usage

``` r
borrow_bathymetry(specs, env_dat, bathy)
```

## Arguments

- specs:

  normalized step specifications

- env_dat:

  covariate data from
  [`fetch_covariates()`](https://camilleross.org/taupatch/reference/fetch_covariates.md)

- bathy:

  a bathymetry `SpatRaster`, or `NULL`

## Value

`list(env_dat=, added=)`, where `added` names the borrowed columns
