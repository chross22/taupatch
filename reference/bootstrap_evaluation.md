# Bootstrap intervals for the evaluation metrics

Resampling gives a standard error for the metrics `tune` computes per
fold, and nothing at all for the rest. `pr_auc`, `tss` and `precision`
are derived from the pooled held-out predictions rather than averaged
over folds, so the fold structure is used up by the pooling and there is
no per-fold spread left to take. Those rows carried `NA`, which said "no
uncertainty available" in a column a reader will read as "no
uncertainty".

## Usage

``` r
bootstrap_evaluation(
  predictions,
  cutoff,
  times = 2000,
  level = 0.95,
  seed = NULL
)
```

## Arguments

- predictions:

  held-out predictions from resampling

- cutoff:

  the TSS-maximising cutoff, from
  [`optimal_threshold()`](https://camilleross.org/taupatch/reference/optimal_threshold.md)

- times:

  how many bootstrap resamples

- level:

  interval width

- seed:

  optional seed, so a run's intervals are reproducible

## Value

a data frame of `metric`, `threshold_kind`, `lower`, `upper`, and
`boot_n`, or `NULL` when the bootstrap cannot run

## Details

This resamples the pooled predictions with replacement and recomputes
every metric on each resample, so every row gets an interval and every
interval means the same thing.

## What the interval covers, and what it does not

It is the sampling variability of **these predictions on these
stations** — how much the number would move if the survey had drawn a
different set of stations from the same population. It does not cover
the variability of refitting the model, which is what the per-fold
`std_err` column reports. The two are different quantities and are kept
in different columns for that reason; neither contains the other.

## The optimal cutoff moves too

The TSS-maximising cutoff is estimated from the same predictions it is
then used to evaluate. Holding it fixed while bootstrapping would report
the metrics at that cutoff as more certain than they are, since a
different sample would have chosen a different cutoff. So each replicate
re-derives its own optimal cutoff and is scored at that, which folds the
cutoff's own instability into the interval — and
`classification_threshold` gets an interval of its own, which is worth
reading before trusting a binarised map.

## See also

[`evaluation_table()`](https://camilleross.org/taupatch/reference/evaluation_table.md),
which merges this into the reported table

## Examples

``` r
predictions <- data.frame(
  patch = factor(rep(c("patch", "non_patch"), c(20, 80)),
                 levels = c("patch", "non_patch")),
  .pred_patch = c(stats::runif(20, 0.4, 0.9), stats::runif(80, 0.05, 0.5))
)
bootstrap_evaluation(predictions, cutoff = 0.4, times = 50)
#>                      metric threshold_kind     lower     upper boot_n
#> 1                   roc_auc           none 0.9533690 0.9951808     50
#> 2                    pr_auc           none 0.8345742 0.9836301     50
#> 3                      sens        default 0.4831522 0.8317029     50
#> 4                      spec        default 1.0000000 1.0000000     50
#> 5                       tss        default 0.4831522 0.8317029     50
#> 6                 precision        default 1.0000000 1.0000000     50
#> 7                      sens        optimal 0.9484962 1.0000000     50
#> 8                      spec        optimal 0.8024324 0.9714744     50
#> 9                       tss        optimal 0.8024324 0.9569570     50
#> 10                precision        optimal 0.4557471 0.8788750     50
#> 11 classification_threshold        optimal 0.4036997 0.4786042     50
```
