# Model-specific diagnostics for a fitted model

Partial effects for every type, since the question "what does this
predictor do" is the same question whichever model answered it. Then the
one thing the chosen model can say that the others cannot: signed
coefficients for a GLM, effective degrees of freedom per smooth for a
GAM. A forest and a boosted ensemble have no such summary — their answer
*is* the partial effect curve, which is why that one is computed for all
four rather than only where an engine happens to report something.

## Usage

``` r
write_effect_plots(model, out)
```

## Arguments

- model:

  a fitted model from
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)

- out:

  the run's diagnostics directory

## Value

character vector of paths written, invisibly
