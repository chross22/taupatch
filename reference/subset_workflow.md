# The workflow for one covariate subset

The same recipe and specification the real fit uses, restricted to a
subset of the predictors — so a jackknifed model differs from the full
one in exactly the covariate that was removed, and not in how it was
preprocessed.

## Usage

``` r
subset_workflow(train, vars, config, type)
```

## Arguments

- train:

  the training rows, carrying `vars` and `patch`

- vars:

  the predictors this model gets

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- type:

  the model type being fitted

## Value

a
[`workflows::workflow()`](https://workflows.tidymodels.org/reference/workflow.html),
not yet fitted
