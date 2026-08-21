# Add staged count columns to mock station data

Reproduces the real database's column set, including its zero-fill
convention for unresolved stages and its
[`rowSums()`](https://rdrr.io/r/base/colSums.html) totals.

## Usage

``` r
add_mock_stage_columns(dat)
```

## Arguments

- dat:

  mock station data with an `abundance_raw` column

## Value

`dat` with stage and total columns for all three taxa
