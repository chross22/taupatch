# One metric's value from a model's evaluation table

The threshold-free metrics live on the rows with no cutoff. Reading them
from here rather than from the resampling table is what lets a single
model and an ensemble be asked the same question — the ensemble's
resampling table is one per member, and its own performance is not the
average of those.

## Usage

``` r
evaluation_value(model, metric = "roc_auc")
```

## Arguments

- model:

  a
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)
  or
  [`fit_patch_ensemble()`](https://camilleross.org/taupatch/reference/fit_patch_ensemble.md)
  result

- metric:

  a threshold-free metric name

## Value

the value, or `NA_real_`
