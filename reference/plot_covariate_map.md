# Map one covariate for one month

What the model was actually given, drawn where it is. A covariate that
failed to download, arrived on the wrong grid, or is masked over the
wrong water is obvious here and invisible in a monthly mean.

## Usage

``` r
plot_covariate_map(env_dat, covariate, year, month, path = NULL)
```

## Arguments

- env_dat:

  covariate data from
  [`fetch_covariates()`](https://camilleross.org/taupatch/reference/fetch_covariates.md),
  or the thinned copy a run returns

- covariate:

  which covariate to draw

- year, month:

  the time step to draw

- path:

  optional file to write the plot to instead of returning it

## Value

a `ggplot` object, or `path` invisibly when writing

## Examples

``` r
if (FALSE) { # \dontrun{
plot_covariate_map(result$covariates, "SST", 2010, 6)
} # }
```
