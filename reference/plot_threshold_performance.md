# Plot performance across classification thresholds

Sensitivity, specificity, and TSS as the probability cutoff moves from 0
to 1, with the TSS-maximising cutoff marked.

## Usage

``` r
plot_threshold_performance(predictions, path = NULL)
```

## Arguments

- predictions:

  the `predictions` element of a
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)
  result

- path:

  where to write a PNG; `NULL` returns the plot instead

## Value

the plot object, or `path` invisibly when written to disk

## Details

The metrics table reports sensitivity and specificity at the default 0.5
cut, which is rarely the right one for imbalanced data — the original
pipeline binarised its projections at a ROC-derived cutoff for exactly
this reason. This shows what the trade-off looks like across the whole
range, and where it is best balanced.
