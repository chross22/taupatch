# Combine the members' out-of-fold predictions

Every member was cross-validated on the same folds from the same seed,
so their held-out predictions cover the same rows and can be combined
row by row. Matched on `.row` rather than on position, since `tune`
returns folds in its own order and two members need not agree on it.

## Usage

``` r
ensemble_oof_predictions(members, weights, rule = "weighted_mean")
```

## Arguments

- members:

  the qualifying
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)
  results

- weights:

  their weights

- rule:

  one of
  [`ensemble_rules()`](https://camilleross.org/taupatch/reference/ensemble_rules.md)

## Value

a data frame of `.row`, `patch` and `.pred_patch`, in the shape the
evaluation functions expect
