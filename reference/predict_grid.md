# Predict patch probability across a covariate grid

Rows with missing predictors are dropped before predicting rather than
predicted and discarded, since the recipe's `step_naomit()` is skipped
at bake time and would otherwise yield NA probabilities.

## Usage

``` r
predict_grid(model, grid, uncertainty = NULL)
```

## Arguments

- model:

  a fitted model from
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)

- grid:

  a covariate grid from
  [`covariate_grid()`](https://camilleross.org/taupatch/reference/covariate_grid.md)

- uncertainty:

  settings from
  [`uncertainty_settings()`](https://camilleross.org/taupatch/reference/uncertainty_settings.md),
  or `NULL` for the point estimate alone

## Value

a tibble of `lon`, `lat`, `suitability`, and, with `uncertainty`, the
spread and novelty columns; `NULL` if no complete rows
