# Fetch bathymetry for the configured study area

Supplies the study area and cache location from the config, so a run's
downloads land with the rest of its outputs rather than wherever R was
started.

## Usage

``` r
study_area_bathymetry(config, resolution = 4)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- resolution:

  grid resolution in arc-minutes; smaller is finer and slower. 4 is
  roughly 7 km at these latitudes.

## Value

a
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with one layer per covariate, in EPSG:4326
