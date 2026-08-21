# Add the configured derived covariates to the covariate grid

Runs each `covariates.derivoce` step in order, passing its fields
straight through to the derivoce function it names. Steps see the
columns the earlier ones produced, so they chain: a `current_speed` step
followed by a `horizontal_gradient` step on `speed` reproduces the
original pipeline's `uv_grad`.

## Usage

``` r
add_derivoce_covariates(env_dat, config, bathy = NULL)
```

## Arguments

- env_dat:

  covariate data from
  [`fetch_covariates()`](https://camilleross.org/taupatch/reference/fetch_covariates.md)

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- bathy:

  optional static bathymetry `SpatRaster` from
  [`datamatch::fetch_bathymetry()`](https://camilleross.org/datamatch/reference/fetch_bathymetry.html),
  needed only by steps reading a depth column

## Value

`env_dat` with one column per derived covariate added

## Details

This runs on the **covariate grid**, before stations are matched to it,
because a gradient or a front is a property of the field and cannot be
recovered from scattered station points. Everything downstream then
treats the results as ordinary covariate columns:
[`attach_covariates()`](https://camilleross.org/taupatch/reference/attach_covariates.md)
matches them to stations,
[`covariate_grid()`](https://camilleross.org/taupatch/reference/covariate_grid.md)
carries them onto the projection grid, and they are picked up as
predictors automatically. Contrast
[`add_derived_covariates()`](https://camilleross.org/taupatch/reference/add_derived_covariates.md),
which adds `jday` to a table of observations and needs one date per row
rather than a grid.

Three consequences are worth stating plainly, since each one costs data:

- Lags, integrals, and temporal gradients are undefined for the first
  time step(s) of the record, so stations in those months are dropped
  when covariates are matched, and the earliest month's projection has
  nothing to predict on.

- A step reading a point's surroundings is undefined on the edge of the
  study area, where the point has no complete neighbourhood. That border
  is lost from both the training stations and the projected maps, so a
  study area drawn to just contain the stations will lose the outermost
  ones.

- A neighbourhood step computed from a variable that was upsampled from
  a coarser product measures the source grid rather than the ocean.
  Those steps warn when their input is one of the upsampled variables
  recorded by
  [`fetch_covariates()`](https://camilleross.org/taupatch/reference/fetch_covariates.md).

## See also

[`derivoce_covariates()`](https://camilleross.org/taupatch/reference/derivoce_covariates.md)
for the step types and the columns they produce

## Examples

``` r
if (FALSE) { # \dontrun{
env_dat <- fetch_covariates(config)
env_dat <- add_derivoce_covariates(env_dat, config)
} # }
```
