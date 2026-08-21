# Threshold-dependent metrics at one cutoff

Computed from the pooled held-out predictions rather than per fold, so
these have no standard error — the fold structure is used up by the
pooling.

## Usage

``` r
metrics_at(predictions, cutoff)
```

## Arguments

- predictions:

  held-out predictions from resampling

- cutoff:

  probability at or above which a cell is called a patch

## Value

a data frame of `metric`, `threshold`, `value`
