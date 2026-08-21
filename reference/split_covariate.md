# Split one covariate out of the product carrying it

A no-op when the product carries only that covariate.

## Usage

``` r
split_covariate(per_dataset, index, covariate)
```

## Arguments

- per_dataset:

  a list of `sf` POINT objects

- index:

  which object to split

- covariate:

  the covariate to separate

## Value

`per_dataset` with the covariate as its own entry
