# Plot a GAM's fitted smooths, with fancyfx

The partial effect of each smooth term on the log-odds scale, with its
standard error band and a rug showing where the data actually is. This
is the exact version of
[`partial_effects()`](https://camilleross.org/taupatch/reference/partial_effects.md)
for a GAM: read out of the fitted model rather than reconstructed by
prediction, so it carries uncertainty, which a partial dependence curve
cannot.

## Usage

``` r
plot_gam_smooths(model, vars = NULL, path = NULL)
```

## Arguments

- model:

  a fitted model from
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)

- vars:

  which smooths to draw; `NULL` uses all of them

- path:

  optional file to write the plot to instead of returning it

## Value

a `patchwork`/`ggplot` object, or `path` invisibly when writing

## Details

Drawn by [fancyfx](https://github.com/chross22/fancyfx), which is a
Suggests — a run without it still gets the generic partial effect
curves.

## Why the axes read in standard deviations

The smooths belong to the model, and the model was fitted on the
recipe's output — so `x` is whatever the recipe made of the predictor.
With the default `covariates.normalize: true` that is standard
deviations from the mean, and the rug is taken from the same baked data
so the two line up. Set `covariates.normalize: false` to have these read
in the covariate's own units; it costs a tree model nothing, and a GAM
little.

## See also

[`gam_smooth_terms()`](https://camilleross.org/taupatch/reference/gam_smooth_terms.md)
for the numbers behind these

## Examples

``` r
if (FALSE) { # \dontrun{
plot_gam_smooths(model)
} # }
```
