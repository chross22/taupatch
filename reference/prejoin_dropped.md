# Covariates a pre-join block removes from the join

A `fill_gaps` source is fetched to fill another covariate, not to be a
predictor, so it does not survive the join unless asked to. Known before
a run so config validation can tell a covariate that will be there from
one that will not.

## Usage

``` r
prejoin_dropped(config)
```

## Arguments

- config:

  a parsed config list

## Value

character vector of covariate names
