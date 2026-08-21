# Project a fitted model to monthly habitat suitability maps

Predicts patch probability across the covariate grid for every
configured month and year. One pooled model produces month-specific maps
because day-of-year is a predictor and the covariates themselves are
monthly — the same arrangement as `original/buildZoopModel.R`, without
the `raster`/`/1000`/manual CRS-string handling it needed to read
biomod2's output back off disk.

## Usage

``` r
project_patch_model(model, env_dat, config, bathy = NULL)
```

## Arguments

- model:

  a fitted model from
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)

- env_dat:

  covariate data from
  [`fetch_covariates()`](https://camilleross.org/taupatch/reference/fetch_covariates.md)

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- bathy:

  optional static bathymetry `SpatRaster` from `fetch_bathymetry()`,
  attached to every month since it does not vary in time

## Value

a tibble with `year`, `month`, `n_cells` (predicted), `n_grid` (cells
available), `resolution` in degrees, and the `geotiff`/`png` paths
written. The suitability table's path is on it as a `table` attribute.

## What it projects onto

Every cell of the covariate grid for that month, not the station
locations. Stations are used to fit the model and play no part here. The
grid's resolution is the one the covariates were joined onto, which
`covariates.grid` decides and any `covariates.prejoin` resampling can
change, so projecting finer means changing those rather than anything in
this block.

Cells missing any predictor are dropped, and the count is reported per
month along with the predictor most often responsible. That is usually a
neighbourhood step, which is undefined on the study-area border, or a
lag, which is undefined in the first month of the record.

## Getting the numbers out

Each month is a GeoTIFF, which carries its own coordinates and is what a
GIS wants. Alongside them goes one `suitability.csv` for the whole run,
in long form: species, year, month, longitude, latitude, probability.
That is the one to read into anything that is not a GIS, and it is
written a month at a time rather than accumulated, since a decade of a
real grid is tens of millions of rows. Set `projection.write_csv` to
`false` to skip it.

Setting `projection.write_grd` to `true` also writes one multi-layer
raster holding every month, layer names carrying the dates. See
[`write_suitability_stack()`](https://camilleross.org/taupatch/reference/write_suitability_stack.md).
