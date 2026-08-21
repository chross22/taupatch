# Add the True Skill Statistic to a metrics table

TSS is sensitivity + specificity - 1. It is computed here from the
cross-validated sensitivity and specificity rather than registered as a
custom yardstick metric, since the value is identical and this avoids
carrying a custom metric class through resampling.

## Usage

``` r
add_tss(metrics)
```

## Arguments

- metrics:

  a
  [`tune::collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
  result

## Value

`metrics` with a `tss` row appended when both inputs are present
