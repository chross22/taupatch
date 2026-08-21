# Variable importance across an ensemble

Each member's permutation importance, weighted by the member's weight
and summed. Permutation importance is the drop in ROC AUC when a
predictor is shuffled, which is the same quantity on the same scale for
all four types — that is exactly why the package computes it itself
rather than asking each engine — so averaging across them means
something.

## Usage

``` r
ensemble_importance(members, weights)
```

## Arguments

- members:

  the qualifying
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)
  results

- weights:

  their weights

## Value

a tibble of `variable`, `importance`, and one column per member

## Details

The per-member columns are kept beside the ensemble figure. A predictor
the forest leans on and the GLM ignores is a fact about the shape of the
relationship, and the average is the one number that hides it.
