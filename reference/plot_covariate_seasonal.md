# Plot a covariate's seasonal cycle, one line per year

The same values the heatmap shows, read the other way: a heatmap is good
at where the record has gaps and poor at how large a departure is,
because the eye cannot compare two colours as precisely as two heights.
A year running warm shows here as a line sitting above the others.

## Usage

``` r
plot_covariate_seasonal(means, covariate = NULL, path = NULL)
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

## Examples

``` r
if (FALSE) { # \dontrun{
plot_covariate_seasonal(result$covariate_means, "SST")
} # }
```
