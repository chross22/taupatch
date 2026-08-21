# Which model type does the jackknifing

The run's own type, normally. An ensemble run has no single type, so it
takes the first member and says so — a covariate test has to be a test
of *something*, and silently picking one of four algorithms would leave
a reader of the table with no way to know which.

## Usage

``` r
jackknife_type(config, settings)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- settings:

  from
  [`jackknife_settings()`](https://camilleross.org/taupatch/reference/jackknife_settings.md)

## Value

a model type name

## Details

`covariates.jackknife.type` overrides both. A GLM is the type to name
there if what is wanted is the classical answer, since it is the one
whose test has an exact form.
