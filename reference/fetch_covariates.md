# Fetch environmental covariates

Dispatches on `covariates.source` in the config. The `"copernicus"`
source fetches from Copernicus Marine via
[`datamatch::accessEnvDat()`](https://camilleross.org/datamatch/reference/accessEnvDat.html);
`"local_netcdf"` reads a directory of NetCDF files already on disk;
`"mock"` generates synthetic covariates so the pipeline can run without
network access.

## Usage

``` r
fetch_covariates(config, years = NULL, months = NULL)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- years:

  years to fetch; defaults to the config's year range

- months:

  months to fetch; defaults to the config's month range

## Value

an `sf` POINT object with one row per (grid point, time step), a column
per covariate variable, and `YEAR`/`MONTH`/`DAY` columns

## Details

All three return the same shape, so everything downstream is
source-agnostic.

## Combining products of different resolution

Copernicus products do not share a grid — physics is 0.083 degrees,
biogeochemistry 0.25 — so selecting `SST` and `CHL` together means two
grids that have to be reconciled onto one.

`covariates.grid` decides which:

- `"finest"` (the default) keeps the finest grid and repeats each coarse
  cell's value across the fine cells inside it. Fine-scale structure in
  the fine variables survives, which matters because fronts and
  gradients are computed from them and a coarse grid would smooth those
  away.

- `"coarsest"` joins onto the coarsest grid instead, so no value is ever
  replicated.

The cost of `"finest"` is worth stating plainly: a coarse variable
rendered on a fine grid is blocky, not detailed. Its values are constant
within each original cell and step at the boundaries, so a **spatial
gradient computed from an upsampled variable is an artifact** — zero
inside each block, spiking at block edges that are an artifact of the
source grid rather than a feature of the ocean. Compute gradients from
variables at their native resolution.

Which covariates were upsampled is recorded on the result as an
`upsampled` attribute.
