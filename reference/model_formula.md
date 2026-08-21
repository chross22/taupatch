# Formula for a model type that needs one

`mgcv` has to be told which terms are smooth, and `parsnip` passes that
as a formula rather than as arguments. Every predictor gets a smooth
except those with too few distinct values to support one: a thin-plate
spline needs more unique points than it has basis functions, and `s()`
on a near-constant column fails rather than degrading. Those enter
linearly, which is what a smooth would have reduced to anyway.

## Usage

``` r
model_formula(type, model_data, predictors, config = NULL)
```

## Arguments

- type:

  a model type name

- model_data:

  the data the model will be fitted on

- predictors:

  predictor column names

## Value

a formula, or `NULL` for types that do not need one
