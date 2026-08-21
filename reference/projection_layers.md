# Layers present on a projection beyond the suitability surface

Which of the optional columns
[`predict_grid()`](https://camilleross.org/taupatch/reference/predict_grid.md)
actually produced. Any of them can come back empty — a model type that
refuses to refit on a resample, an ensemble member that will not predict
this month's grid — and a map is written either way rather than the run
failing at the last step.

## Usage

``` r
projection_layers(predicted)
```

## Arguments

- predicted:

  a projection from
  [`predict_grid()`](https://camilleross.org/taupatch/reference/predict_grid.md)

## Value

character vector of column names beyond `suitability`

## Details

Three different quantities can appear here and they are deliberately not
merged. `suitability_sd` is one algorithm refitted on resampled
stations; `algorithm_sd` is different algorithms on the same stations;
`novelty` is how far outside the training data the cell sits. A cell can
be quiet on one and loud on another, and that is the informative case
rather than a contradiction.

Character columns are excluded by construction: these names become
raster layers, and `novel_variable` travels in the CSV instead.
