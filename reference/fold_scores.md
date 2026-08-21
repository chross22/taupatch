# One model's score on every fold

Fitted and scored by hand rather than through
[`tune::fit_resamples()`](https://tune.tidymodels.org/reference/fit_resamples.html),
for one reason: the per-fold numbers are the whole point here, and they
have to come from the *same* `rsample` folds for every covariate subset
so the differences pair up. Going through `tune` would mean re-deriving
the folds inside each call and getting the pairing only by luck.

## Usage

``` r
fold_scores(vars, folds, config, type, metric = "roc_auc")
```

## Arguments

- vars:

  the predictors this model gets

- folds:

  the shared
  [`rsample::vfold_cv()`](https://rsample.tidymodels.org/reference/vfold_cv.html)
  object

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- type:

  the model type being fitted

- metric:

  `"roc_auc"` or `"pr_auc"`

## Value

a numeric vector, one score per fold

## Details

A fold that will not fit — a subset with one predictor that is constant
on that split, say — scores `NA` rather than failing the run, and the
test downstream drops it and reports the reduced `n_folds`.
