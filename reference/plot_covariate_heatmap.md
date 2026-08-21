# Plot a month-by-year heatmap of a covariate

Shows the study-area mean of one covariate for every month and year,
which makes the seasonal cycle read down each column and interannual
change read across rows. Useful for spotting gaps in the covariate
record and for sanity- checking that a fetched variable behaves the way
it should (SST peaking in late summer, for instance).

## Usage

``` r
plot_covariate_heatmap(means, covariate = NULL, path = NULL)
```

## Arguments

- means:

  a data frame from
  [`covariate_monthly_means()`](https://camilleross.org/taupatch/reference/covariate_monthly_means.md)

- covariate:

  which covariate to plot; defaults to the first present

- path:

  where to write a PNG; `NULL` returns the plot instead

## Value

the plot object, or `path` invisibly when written to disk

## Examples

``` r
if (FALSE) { # \dontrun{
result <- run_taupatch("inst/configs/mock_test.yaml")
plot_covariate_heatmap(result$covariate_means, "SST")
} # }
```
