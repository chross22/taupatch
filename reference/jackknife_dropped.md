# Which covariates a jackknife would drop

The `keep` list and `min_predictors` floor applied to the test result.
Split out from the run so a report-only jackknife can still say what
dropping *would* have removed, which is the number worth seeing before
turning `drop` on.

## Usage

``` r
jackknife_dropped(jk, settings = attr(jk, "settings"))
```

## Arguments

- jk:

  the result of
  [`jackknife_covariates()`](https://camilleross.org/taupatch/reference/jackknife_covariates.md)

- settings:

  from
  [`jackknife_settings()`](https://camilleross.org/taupatch/reference/jackknife_settings.md).
  Defaults to the settings the jackknife was actually run under, which
  it carries on itself — so asking a result what it would drop needs
  nothing but the result.

## Value

a character vector of covariate names, possibly empty

## Details

When the floor binds, the covariates kept are the ones that contributed
most, so a run that would have dropped everything keeps the best of a
bad set rather than an arbitrary one.

## See also

[`jackknife_covariates()`](https://camilleross.org/taupatch/reference/jackknife_covariates.md)

## Examples

``` r
jk <- data.frame(
  variable = c("SST", "SSS", "CHL"),
  contribution = c(0.08, 0.001, 0.0005),
  significant = c(TRUE, FALSE, FALSE)
)
settings <- list(keep = character(), min_predictors = 2)
jackknife_dropped(jk, settings)      # only the weakest: the floor binds at 2
#> [1] "CHL"

jackknife_dropped(jk, list(keep = "CHL", min_predictors = 1))
#> [1] "SSS"
```
