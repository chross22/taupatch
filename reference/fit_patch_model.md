# Fit a patch habitat suitability model

Fits a tidymodels workflow classifying stations as inside or outside a
high-abundance patch. Replaces the `biomod2` model in
`original/buildZoopModel.R`: cross-validation via
[`rsample::vfold_cv()`](https://rsample.tidymodels.org/reference/vfold_cv.html)
instead of biomod2's `CV.nb.rep`/`data.split.perc`, and a
[`workflows::workflow()`](https://workflows.tidymodels.org/reference/workflow.html)
object instead of biomod2's on-disk model directory and string-pasted
run names.

## Usage

``` r
fit_patch_model(dat, config)
```

## Arguments

- dat:

  labeled modeling data from
  [`label_patch()`](https://camilleross.org/taupatch/reference/label_patch.md)
  with covariates attached

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

a list with `workflow` (the fitted workflow), `metrics` (cross-validated
performance), `importance` (permutation variable importance), `type`
(the model type fitted), `model_data` (what it was fitted on),
`predictors`, and `threshold`

## References

Kuhn M, Wickham H (2020). *Tidymodels: a collection of packages for
modeling and machine learning using tidyverse principles*.
<https://www.tidymodels.org>

Thuiller W, Lafourcade B, Engler R, Araújo MB (2009). BIOMOD - a
platform for ensemble forecasting of species distributions. *Ecography*
**32**(3), 369-373.
[doi:10.1111/j.1600-0587.2008.05742.x](https://doi.org/10.1111/j.1600-0587.2008.05742.x)
— what this replaces

See
[`model_types()`](https://camilleross.org/taupatch/reference/model_types.md)
for the reference behind each model, and
[`evaluation_table()`](https://camilleross.org/taupatch/reference/evaluation_table.md)
for the metrics.
