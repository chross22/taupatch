# Cross-validated metrics for the combined ensemble

The ensemble's own held-out predictions, scored per fold and summarised
in the shape
[`tune::collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
returns — so everything downstream that reads a metrics table reads this
one without knowing an ensemble produced it.

## Usage

``` r
ensemble_cv_metrics(predictions)
```

## Arguments

- predictions:

  the combined out-of-fold predictions

## Value

a data frame of `.metric`, `.estimator`, `mean`, `n`, `std_err`, with a
`tss` row; `NULL` when the folds are not recoverable

## Details

Computed on the ensemble rather than averaged over members, because
those are different numbers and only the first is the ensemble's
performance: combining members that make different mistakes beats every
one of them, and combining members that make the same mistakes does not.

The threshold-dependent rows are at the default 0.5 cutoff, which is
what the equivalent rows mean for a single model.
[`evaluation_table()`](https://camilleross.org/taupatch/reference/evaluation_table.md)
restates them at the TSS-optimal cutoff alongside.
