# Abundance over the record

One point per station against its own year and month, with the monthly
median over the top. The seasonal cycle, the swings between years, and
the months nobody sampled all read from the same picture.

## Usage

``` r
plot_station_series(dat, path = NULL)
```

## Arguments

- dat:

  station data from
  [`load_zoop_data()`](https://camilleross.org/taupatch/reference/load_zoop_data.md)

- path:

  optional file to write the plot to instead of returning it

## Value

a `ggplot` object, or `path` invisibly when writing

## Examples

``` r
if (FALSE) { # \dontrun{
plot_station_series(load_zoop_data(config))
} # }
```
