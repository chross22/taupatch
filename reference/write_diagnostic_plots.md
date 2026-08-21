# Write model diagnostic plots

All four are drawn from held-out cross-validation predictions, so they
describe performance on data the model did not see. The predictions
themselves are saved alongside, so a diagnostic not covered here can be
produced without refitting.

## Usage

``` r
write_diagnostic_plots(model, out)
```

## Arguments

- model:

  a fitted model from
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)

- out:

  the run's output directory

## Value

`NULL`, invisibly

## Details

Alongside them go the effect plots, which depend on which model was
fitted: partial effects for every type, plus coefficients for a GLM or
smooth terms for a GAM. See
[`write_effect_plots()`](https://camilleross.org/taupatch/reference/write_effect_plots.md).
