# Build the preprocessing recipe

Applies the transformations named in `covariates.transform`, then
normalizes all numeric predictors unless `covariates.normalize` turns
that off. The original applied `log(abs(x))` to a hardcoded trio of
chlorophyll, integrated chlorophyll, and bathymetry
(`original/buildZoopModel.R:134-136`); which covariates need which
transform is now config. See
[`covariate_transforms()`](https://camilleross.org/taupatch/reference/covariate_transforms.md)
for what is available and what each one can safely be given.

## Usage

``` r
build_recipe(model_data, config)
```

## Arguments

- model_data:

  data frame of predictors plus the `patch` response

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

a
[`recipes::recipe`](https://recipes.tidymodels.org/reference/recipe.html)

## Details

The default transform remains `log1p(abs(x))` rather than `step_log()`.
It preserves the original's
[`abs()`](https://rdrr.io/r/base/MathFun.html), which exists because
bathymetry is stored as negative depth, while remaining defined at zero
— `step_log(signed = TRUE)` returns `-Inf` at zero and silently ignores
an `offset` meant to prevent that, and zeros are common in these
covariates.

Normalizing costs a tree model nothing and matters to everything else,
so it stays on by default and is a knob rather than a decision the
engine choice makes silently.
