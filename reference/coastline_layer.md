# A coastline under a station map

Points on an empty background say where stations are relative to each
other and nothing about where they are. A coastline is the difference
between a scatter plot and a map.

## Usage

``` r
coastline_layer(dat, margin = 2)
```

## Arguments

- dat:

  station data, used to size the extent fetched

- margin:

  degrees of coast to include beyond the stations

## Value

a `ggplot2` layer, or `NULL` when the coastline is unavailable

## Details

`rnaturalearth` is a Suggests, so a map without it is the scatter plot:
worth less, but not worth failing over.
