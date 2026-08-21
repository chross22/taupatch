# Write model artifacts to the output directory

The same artifacts the original pipeline produced (evaluations, variable
importance, the fitted model), without biomod2's nested directory
layout.

## Usage

``` r
write_model_outputs(model, config)
```

## Arguments

- model:

  a fitted model from
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

`NULL`, invisibly
