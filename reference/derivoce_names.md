# Column names the configured derivoce steps will produce

Known before a run, which is what lets `covariates.log_transform` name a
derived covariate and what lets the config be validated without fetching
anything.

## Usage

``` r
derivoce_names(config)
```

## Arguments

- config:

  a parsed config list

## Value

character vector of derived column names, in the order produced
