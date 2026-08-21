# The members' cross-validated metrics, stacked

One
[`tune::collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
table per member with a `type` column added, so the run's
`cv_metrics.csv` says which algorithm each row belongs to instead of
silently reporting one of them.

## Usage

``` r
member_metrics(members)
```

## Arguments

- members:

  the
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)
  results

## Value

a data frame
