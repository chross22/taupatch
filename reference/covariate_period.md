# Years and months covariates are needed for

The union of the training and projection windows: training needs
covariates to match to stations, projection needs them to predict over.
Fetching the union as two sets rather than one spanning range avoids
downloading the gap between windows that are far apart.

## Usage

``` r
covariate_period(config)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

`list(years=, months=)`, each a sorted vector
