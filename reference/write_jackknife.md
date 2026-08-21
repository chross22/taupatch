# Write the covariate jackknife table

Written whether or not anything was dropped, and written before the
model is fitted, so a run that turned `drop` on leaves a record of what
it removed and on what evidence.

## Usage

``` r
write_jackknife(jk, config)
```

## Arguments

- jk:

  the result of
  [`jackknife_covariates()`](https://camilleross.org/taupatch/reference/jackknife_covariates.md)

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

`NULL`, invisibly
