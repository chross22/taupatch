# Label high-abundance patches

Classifies each station as inside or outside a high-abundance patch,
using either a percentile of the observed abundance distribution or an
absolute abundance value.

## Usage

``` r
label_patch(dat, config, min_rows = 100)
```

## Arguments

- dat:

  station data from
  [`load_zoop_data()`](https://camilleross.org/taupatch/reference/load_zoop_data.md)

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- min_rows:

  minimum rows required to fit a usable model

## Value

`dat` with an added `patch` factor whose first level is `"patch"`, and a
`threshold` attribute recording the abundance value used
