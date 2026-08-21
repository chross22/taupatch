# Variables a fitted GAM gave a smooth to

Not every predictor gets one —
[`model_formula()`](https://camilleross.org/taupatch/reference/model_formula.md)
gives a linear term to any predictor with too few distinct values to
identify a smooth — so this reads back what the fitted model actually
did rather than assuming.

## Usage

``` r
gam_smoothed_variables(fitted)
```

## Arguments

- fitted:

  a fitted
  [`workflows::workflow()`](https://workflows.tidymodels.org/reference/workflow.html)
  whose model is an `mgcv` GAM

## Value

character vector of variable names, in the model's own order
