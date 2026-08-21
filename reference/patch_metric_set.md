# Metric set for patch models

ROC AUC, Cohen's kappa, sensitivity, and specificity — the first three
matching the original's `metric.eval = c('ROC', 'TSS', 'KAPPA')`. TSS is
derived from sensitivity and specificity afterwards by
[`add_tss()`](https://camilleross.org/taupatch/reference/add_tss.md).

## Usage

``` r
patch_metric_set()
```

## Value

a `yardstick` metric set
