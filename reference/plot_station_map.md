# Map the stations, coloured by abundance

Where the survey actually went, and where the animals were. Worth
looking at before fitting anything: a study area drawn wider than the
stations, a year that sampled only half the shelf, or an abundance field
that is all zeros outside one corner are all visible here and invisible
in a metrics table.

## Usage

``` r
plot_station_map(dat, transform = c("log1p", "none"), path = NULL)
```

## Arguments

- dat:

  station data from
  [`load_zoop_data()`](https://camilleross.org/taupatch/reference/load_zoop_data.md)

- transform:

  how to scale the colour; abundance spans orders of magnitude, so the
  default is log1p

- path:

  optional file to write the plot to instead of returning it

## Value

a `ggplot` object, or `path` invisibly when writing

## Examples

``` r
if (FALSE) { # \dontrun{
plot_station_map(load_zoop_data(config))
} # }
```
