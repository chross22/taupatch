# The jackknife settings a run would use with nothing configured

[`jackknife_covariates()`](https://camilleross.org/taupatch/reference/jackknife_covariates.md)
can be called on a config with no jackknife block at all — testing
covariates is a reasonable thing to do interactively without editing a
file for it — and this is what it uses then.

## Usage

``` r
jackknife_defaults()
```

## Value

the same shape
[`jackknife_settings()`](https://camilleross.org/taupatch/reference/jackknife_settings.md)
returns
