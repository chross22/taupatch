# Plot the precision-recall curve

More informative than ROC when the classes are imbalanced, which they
are here by construction: a 90th-percentile threshold makes only 10% of
stations patches. ROC uses the false positive rate, whose denominator is
the large non-patch class, so a model can look excellent while most of
its positive predictions are still wrong. Precision asks the question
that actually matters for a patch map — of the places called patch, how
many are?

## Usage

``` r
plot_pr_curve(predictions, path = NULL)
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

The baseline is the patch prevalence: what precision random guessing
achieves.
