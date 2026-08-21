# Plot a covariate's annual mean over the record

Collapses each year's months to one value, which is the view that shows
drift across the record rather than the seasonal cycle riding on top of
it.

## Usage

``` r
plot_covariate_annual(means, covariate = NULL, path = NULL)
```

## Arguments

- means:

  a data frame from
  [`covariate_monthly_means()`](https://camilleross.org/taupatch/reference/covariate_monthly_means.md)

- covariate:

  which covariate to plot; defaults to the first

- path:

  optional file to write the plot to instead of returning it

## Value

a `ggplot` object, or `path` invisibly when writing

## Details

The mean is taken over whichever months the run fetched. That makes the
series comparable between years only when every year covers the same
months — which is the normal case here, since covariates are fetched for
a fixed month range, but is worth knowing before reading a trend into
it.

## Examples

``` r
if (FALSE) { # \dontrun{
plot_covariate_annual(result$covariate_means, "SST")
} # }
```
