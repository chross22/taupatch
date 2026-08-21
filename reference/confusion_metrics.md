# Sensitivity, specificity, TSS and precision from a thresholded prediction

The arithmetic on its own, with no data frame around it. The reported
table and the bootstrap both go through here, so the two cannot come to
disagree about what a metric is — and the bootstrap can call it a few
thousand times without paying for a data frame each time.

## Usage

``` r
confusion_metrics(called, is_patch)
```

## Arguments

- called:

  logical, whether each observation was called a patch

- is_patch:

  logical, whether each observation is one

## Value

a named numeric vector
