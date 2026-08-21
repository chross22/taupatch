# Predictions from every member of one resample ensemble, as a matrix

The half of
[`ensemble_spread()`](https://camilleross.org/taupatch/reference/ensemble_spread.md)
that produces the numbers, without reducing them — so an ensemble of
ensembles can pool the replicates before taking quantiles rather than
taking quantiles of quantiles.

## Usage

``` r
ensemble_spread_matrix(ensemble, newdata)
```

## Arguments

- ensemble:

  a list of fitted workflows

- newdata:

  the cells to predict

## Value

a matrix of cells by members, or `NULL`
