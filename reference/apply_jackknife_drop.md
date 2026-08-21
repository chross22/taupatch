# Remove the covariates a jackknife rejected

Written into `covariates.exclude`, which is the mechanism that already
existed for keeping a fetched covariate out of the model, rather than a
second one beside it. So a dropped covariate is still downloaded and
still available to anything downstream that wants it — including a
derived covariate that needs it as an ingredient — it just stops being a
predictor.

## Usage

``` r
apply_jackknife_drop(config, dropped)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- dropped:

  covariate names to exclude

## Value

`config`, with `covariates.exclude` extended
