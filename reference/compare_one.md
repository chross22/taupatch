# Compare one run against the reference

Compare one run against the reference

## Usage

``` r
compare_one(
  reference_predictions,
  other_predictions,
  reference,
  comparison,
  metric = "roc_auc",
  level = 0.95,
  power = 0.8
)
```

## Arguments

- reference_predictions:

  held-out predictions of the reference run

- other_predictions:

  held-out predictions of the run being compared

- reference:

  the reference run's name

- comparison:

  the other run's name

- metric:

  `"roc_auc"` or `"pr_auc"`

- level:

  confidence level

- power:

  the power `detectable` is computed at

## Value

a one-row data frame
