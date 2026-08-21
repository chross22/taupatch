# Summary of a station dataset

The numbers worth knowing before fitting: how many stations, over what
period and area, and how the abundances are distributed. The proportion
of zeros is the one that most often explains a disappointing model.

## Usage

``` r
station_summary(dat)
```

## Arguments

- dat:

  station data from
  [`load_zoop_data()`](https://camilleross.org/taupatch/reference/load_zoop_data.md)

## Value

a data frame of `quantity` and `value`

## Examples

``` r
if (FALSE) { # \dontrun{
station_summary(load_zoop_data(config))
} # }
```
