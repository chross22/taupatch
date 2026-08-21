# Build a leaflet map of a projection GeoTIFF

Build a leaflet map of a projection GeoTIFF

## Usage

``` r
projection_map(geotiff, opacity = 0.8)
```

## Arguments

- geotiff:

  path to a projection GeoTIFF written by
  [`project_patch_model()`](https://camilleross.org/taupatch/reference/project_patch_model.md)

- opacity:

  overlay opacity

## Value

a `leaflet` map widget

## Examples

``` r
if (FALSE) { # \dontrun{
result <- run_taupatch("inst/configs/mock_test.yaml")
projection_map(result$projections$geotiff[1])
} # }
```
