# Plot probability calibration

Whether predicted probabilities mean what they say: of the cells given a
0.7 chance of being a patch, are about 70% patches?

## Usage

``` r
plot_calibration(predictions, bins = 10, path = NULL)
```

## Arguments

- predictions:

  the `predictions` element of a
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)
  result

- bins:

  number of probability bins

- path:

  where to write a PNG; `NULL` returns the plot instead

## Value

the plot object, or `path` invisibly when written to disk

## Details

This matters for a suitability map specifically. The maps are read as
probabilities and compared between months and regions, but a model can
rank cells perfectly — a high AUC — while its probabilities are
systematically too confident or too timid. Ranking is all AUC measures;
calibration is what makes the number on the map mean something.

Random forests are commonly under-confident at the extremes, since a
probability is a vote share across trees and unanimity is rare.
