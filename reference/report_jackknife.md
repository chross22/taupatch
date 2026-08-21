# Say what the jackknife found, in one place

A table of fifteen columns is not something a run's log can print, and
the one thing a reader needs from it mid-run is which covariates failed
and whether anything is about to be removed on the strength of that.

## Usage

``` r
report_jackknife(jk, settings)
```

## Arguments

- jk:

  the result of
  [`jackknife_covariates()`](https://camilleross.org/taupatch/reference/jackknife_covariates.md)

- settings:

  from
  [`jackknife_settings()`](https://camilleross.org/taupatch/reference/jackknife_settings.md)

## Value

`NULL`, invisibly
