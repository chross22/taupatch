# Average each covariate over the study area, per month and year

Collapses the covariate grid to one value per (year, month, covariate) —
the spatial mean across the study area. Summarizing during a run rather
than returning the full grid keeps the result small: a multi-decade
Copernicus fetch is millions of grid points, while its summary is a few
hundred rows.

## Usage

``` r
covariate_monthly_means(env_dat, vars = NULL)
```

## Arguments

- env_dat:

  covariate data from
  [`fetch_covariates()`](https://camilleross.org/taupatch/reference/fetch_covariates.md)

- vars:

  covariate names to summarize; `NULL` uses all of them

## Value

a data frame with `year`, `month`, `covariate`, and `mean` columns
