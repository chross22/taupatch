# Plot a monthly habitat suitability projection

Plot a monthly habitat suitability projection

## Usage

``` r
plot_projection(predicted, year, month, species, path)
```

## Arguments

- predicted:

  a projection from
  [`predict_grid()`](https://camilleross.org/taupatch/reference/predict_grid.md),
  with `lon`/`lat`/`suitability`

- year:

  year being projected

- month:

  month being projected

- species:

  species name, for the title

- path:

  where to write the PNG

## Value

`path`, invisibly
