# Transformations a config applies, as a named list

Resolves the older `covariates.log_transform` onto the
`covariates.transform` block, so a config written before there was a
choice keeps working and means what it always meant.

## Usage

``` r
covariate_transform_spec(config)
```

## Arguments

- config:

  a parsed config list

## Value

a named list of transform name to covariate names, possibly empty
