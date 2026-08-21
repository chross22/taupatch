# The likelihood-based test, where the model type has one

A GLM gets a drop-in-deviance likelihood ratio test against each nested
model, which is exact. A GAM gets `mgcv`'s approximate p-value for the
term, which is not — it conditions on smoothing parameters estimated
from the same data and so runs anti-conservative. A forest and a boosted
tree get `NA`, because there is no likelihood to take a ratio of.

## Usage

``` r
parametric_tests(model_data, predictors, config, type)
```

## Arguments

- model_data:

  the complete-case modeling data

- predictors:

  predictor column names

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- type:

  the model type being fitted

## Value

a list of `p_value` (one per predictor, in order) and `test` (a label)

## Details

Fitted on the whole dataset rather than per fold: this is a test about
the model, not about its generalization, which is exactly what makes it
a different reading from the fold test beside it.
