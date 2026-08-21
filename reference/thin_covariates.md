# Thin a covariate grid to a bounded number of cells

A Copernicus fetch over a decade is millions of grid points, which is
why
[`run_taupatch()`](https://camilleross.org/taupatch/reference/run_taupatch.md)
summarises the covariates rather than returning them. But a summary
cannot be mapped, and a map is the fastest way to see that a covariate
is wrong — a field of zeros, a land mask in the wrong place, a month
that failed to download.

## Usage

``` r
thin_covariates(env_dat, max_cells = 50000)
```

## Arguments

- env_dat:

  covariate data from
  [`fetch_covariates()`](https://camilleross.org/taupatch/reference/fetch_covariates.md)

- max_cells:

  the most rows to keep across all time steps

## Value

`env_dat`, or a subsample of its locations

## Details

This keeps a regular subsample: every nth location, the same ones in
every time step, chosen so the whole object stays under `max_cells`. A
map drawn from it is coarser than the data and shows the same thing,
which is what it is for. Nothing modelled is thinned; this is a copy
kept for looking at.

Locations rather than rows, because dropping rows at random would give a
different set of points each month and a map that flickers between them.

## Examples

``` r
if (FALSE) { # \dontrun{
thin_covariates(env_dat, max_cells = 20000)
} # }
```
