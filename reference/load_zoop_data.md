# Load zooplankton station data

Reads the zooplankton database CSV, keeping only the columns the config
declares, and filters to the configured years, months, source datasets,
and study-area bounding box. Abundance for the active species comes
either from a named column or by summing every column matching a stage
prefix.

## Usage

``` r
load_zoop_data(config)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

a tibble with `lon`, `lat`, `year`, `month`, `day`, `jday`, and
`abundance`, one row per station visit
