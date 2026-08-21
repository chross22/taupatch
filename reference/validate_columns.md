# Check the config's declared columns against the CSV header

Reads the header only, never any data rows, so a config can be validated
against a dataset without loading it.

## Usage

``` r
validate_columns(config)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

`TRUE` invisibly; errors listing every missing column otherwise
