# Assemble a self-explanatory evaluation table

The cross-validated metrics table reports sensitivity, specificity and
kappa at the default 0.5 cutoff without saying so anywhere. That is
badly misleading when the classes are imbalanced — and they are here by
construction, since a 90th-percentile abundance threshold makes only a
tenth of stations patches. At 0.5 a random forest calls almost nothing a
patch, so sensitivity reads as poor when the model is not.

## Usage

``` r
evaluation_table(predictions, cv_metrics, cutoff, bounds = NULL)
```

## Arguments

- predictions:

  held-out predictions from resampling

- cv_metrics:

  the
  [`tune::collect_metrics()`](https://tune.tidymodels.org/reference/collect_predictions.html)
  result, with TSS added

- cutoff:

  the TSS-maximising cutoff

- bounds:

  the result of
  [`bootstrap_evaluation()`](https://camilleross.org/taupatch/reference/bootstrap_evaluation.md),
  or `NULL` to leave the interval columns empty

## Value

a data frame with `metric`, `threshold`, `value`, `std_err`, `lower`,
`upper`, and `note` columns

## Details

This states the cutoff each metric belongs to, and reports the
threshold-dependent ones twice: at 0.5, and at the cutoff that maximises
TSS. Threshold-free metrics carry `NA` in that column, which is the
honest entry — they do not have one.

## Two kinds of uncertainty, in two columns

`std_err` is the spread across cross-validation folds, and only the
metrics `tune` averages per fold have one — `pr_auc`, `tss` and
`precision` are computed from the pooled held-out predictions, which
uses the fold structure up. `lower` and `upper` come from
[`bootstrap_evaluation()`](https://camilleross.org/taupatch/reference/bootstrap_evaluation.md)
instead and are present for every row.

They are not two estimates of the same thing. The fold standard error is
about refitting the model; the bootstrap interval is about which
stations the survey happened to sample. A metric can be stable under one
and not the other.

## References

Allouche O, Tsoar A, Kadmon R (2006). Assessing the accuracy of species
distribution models: prevalence, kappa and the true skill statistic
(TSS). *Journal of Applied Ecology* **43**(6), 1223-1232.
[doi:10.1111/j.1365-2664.2006.01214.x](https://doi.org/10.1111/j.1365-2664.2006.01214.x)
— `tss`

Saito T, Rehmsmeier M (2015). The precision-recall plot is more
informative than the ROC plot when evaluating binary classifiers on
imbalanced datasets. *PLoS ONE* **10**(3), e0118432.
[doi:10.1371/journal.pone.0118432](https://doi.org/10.1371/journal.pone.0118432)
— `pr_auc`

Sofaer HR, Hoeting JA, Jarnevich CS (2019). The area under the
precision-recall curve as a performance metric for rare binary events.
*Methods in Ecology and Evolution* **10**(4), 565-577.
[doi:10.1111/2041-210X.13140](https://doi.org/10.1111/2041-210X.13140) —
the same argument for rare events in species distribution models, which
is what a patch is
