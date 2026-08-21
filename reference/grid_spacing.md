# Grid spacing of a covariate source, in degrees

The measurement is
[`datamatch::grid_resolution()`](https://camilleross.org/datamatch/reference/grid_resolution.html),
which owns it; this reduces its per-axis answer to the single number the
join needs, the coarser of the two. A grid finer in one direction than
the other is still limited by its coarse direction, so that is what
decides which source is the finer of two.

## Usage

``` r
grid_spacing(env_dat)
```

## Arguments

- env_dat:

  an `sf` POINT object from
  [`datamatch::accessEnvDat()`](https://camilleross.org/datamatch/reference/accessEnvDat.html)

## Value

the coarser of the longitude and latitude spacings
