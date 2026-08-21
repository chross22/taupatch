# One covariate's rows from a monthly-means table

One covariate's rows from a monthly-means table

## Usage

``` r
covariate_subset(means, covariate = NULL)
```

## Arguments

- means:

  a data frame from
  [`covariate_monthly_means()`](https://camilleross.org/taupatch/reference/covariate_monthly_means.md)

- covariate:

  a covariate name, or `NULL` for the first

## Value

the matching rows; errors listing what is available if there are none
