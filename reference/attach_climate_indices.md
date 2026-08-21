# Attach the configured climate indices to a table

Joined on year and month, since that is the resolution the indices are
published at and the resolution this pipeline runs at.

## Usage

``` r
attach_climate_indices(dat, config, year_col = "year", month_col = "month")
```

## Arguments

- dat:

  a data frame with year and month columns

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- year_col, month_col:

  the columns to join on

## Value

`dat` with one column per configured index
