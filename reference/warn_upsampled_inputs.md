# Warn when a neighbourhood step reads an upsampled variable

Warn when a neighbourhood step reads an upsampled variable

## Usage

``` r
warn_upsampled_inputs(spec, entry, upsampled)
```

## Arguments

- spec:

  a normalized step specification

- entry:

  the matching
  [`derivoce_covariates()`](https://camilleross.org/taupatch/reference/derivoce_covariates.md)
  entry

- upsampled:

  variables recorded as upsampled by
  [`fetch_covariates()`](https://camilleross.org/taupatch/reference/fetch_covariates.md)

## Value

`NULL`, invisibly
