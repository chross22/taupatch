# The underlying engine object from a fitted model

The `ranger`, `xgb.Booster`, `glm`, or `gam` object inside the workflow,
rather than the workflow wrapping it. Anything that plots or
interrogates a model directly needs this rather than the tidymodels
object — including [fancyfx](https://github.com/chross22/fancyfx), whose
`plotEffects()` takes an `mgcv` fit, which is what this returns for
`model.type: gam`.

## Usage

``` r
model_engine_fit(model)
```

## Arguments

- model:

  a fitted model from
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md),
  or a fitted workflow

## Value

the engine's own fitted object

## Examples

``` r
if (FALSE) { # \dontrun{
# Prettier smooths than the generic partial effects can give:
fancyfx::plotEffects(model_engine_fit(model), dat, "SST")
} # }
```
