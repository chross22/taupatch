# Resolve a step's target grid

A covariate name means "that covariate's grid", which is how a config
says "put chlorophyll where the physics is" without knowing what
resolution the physics happens to be. A number is a resolution in
degrees.

## Usage

``` r
prejoin_target(per_dataset, to)
```

## Arguments

- per_dataset:

  a list of `sf` POINT objects

- to:

  a covariate name or a numeric resolution

## Value

an `sf` object or a number, as `datamatch` expects
