# One point on the power curve

Draws a subsample, folds it, and scores every config on those same
folds.

## Usage

``` r
power_point(
  model_data,
  configs,
  predictors,
  types,
  fraction,
  replicate,
  metric = "roc_auc",
  seed = 42
)
```

## Arguments

- model_data:

  the complete-case modeling data

- configs:

  the configs being compared

- predictors:

  each config's predictors

- types:

  each config's model type

- fraction:

  the share of stations to draw

- replicate:

  which draw this is

- metric:

  `"roc_auc"` or `"pr_auc"`

- seed:

  the run's seed

## Value

a one-row data frame, or `NULL` when the draw could not be scored
