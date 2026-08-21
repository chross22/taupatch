# Validate the derivoce block

Walks the steps in order, so a step may read what an earlier one
produced and an out-of-order config is reported as a missing covariate
rather than failing partway through a run.

## Usage

``` r
validate_derivoce(config)
```

## Arguments

- config:

  a parsed config list

## Value

`TRUE` invisibly; errors otherwise
