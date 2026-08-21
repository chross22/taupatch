# The fitted models an interval is built from

Cross-validation already fits one model per fold and then throws them
away. Asking `tune` to hand them back costs nothing, so the default
ensemble is free: the only extra work a projection does is predicting
from each member.

## Usage

``` r
projection_ensemble(resampled, workflow, model_data, settings)
```

## Arguments

- resampled:

  the
  [`tune::fit_resamples()`](https://tune.tidymodels.org/reference/fit_resamples.html)
  result, fitted with `control_resamples(extract = )`

- workflow:

  the workflow to refit, for `bootstrap`

- model_data:

  the data to refit on, for `bootstrap`

- settings:

  from
  [`uncertainty_settings()`](https://camilleross.org/taupatch/reference/uncertainty_settings.md)

## Value

a list of fitted workflows

## Details

`bootstrap` refits instead, which does cost, and buys the one thing
folds cannot give — enough members for a quantile to mean something. Ten
folds support a spread; they do not support a 95% interval, because the
2.5th percentile of ten numbers is the smallest of them.
