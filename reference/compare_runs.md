# Is the gap between two model runs real?

Two runs come back with two numbers — ROC AUC 0.857 against 0.871 — and
nothing in either says whether the gap is a difference between the
models or a difference between the stations the survey happened to
visit. This answers that, and answers the question that should be asked
next when the gap is not significant: **how large would a difference
have had to be before this study could have seen it?**

## Usage

``` r
compare_runs(runs, metric = "roc_auc", level = 0.95, power = 0.8)
```

## Arguments

- runs:

  a named list of two or more fitted runs, from
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)
  or
  [`fit_patch_ensemble()`](https://camilleross.org/taupatch/reference/fit_patch_ensemble.md).
  The first is the reference every other is compared against.

- metric:

  `"roc_auc"` or `"pr_auc"`; both are threshold-free, which is what lets
  them be compared fold by fold without a cutoff moving underneath

- level:

  confidence level for the interval and the test

- power:

  the power `detectable` is computed at

## Value

a data frame with one row per comparison against the reference:
`reference`, `comparison`, `metric`, `reference_score`,
`comparison_score`, `difference` (comparison minus reference), `lower`,
`upper`, `statistic`, `df`, `p_value`, `detectable`, `n_folds`,
`n_stations`, and `n_dropped`

## Details

Those two are reported together deliberately. "Not significant" on its
own is the least informative result in modelling — it conflates *these
models perform alike* with *this survey could not have told them apart*,
and `detectable` is what separates the two. A run that cannot detect
anything smaller than 0.09 in AUC has not shown that a 0.014 gap is
absent.

## How the comparison is paired

Every run cross-validates, so each carries a metric per fold rather than
one number, and two runs on the same stations can be compared fold by
fold. That pairing is most of the statistical power available: the folds
vary a great deal between themselves and much less between two models
scored on the *same* fold, and an unpaired comparison throws that away.

Runs are matched on `.row`, the station index, not on position. Two runs
with different covariates drop different stations to missingness, so the
comparison is made on the stations both actually scored and the number
dropped is reported. A run that drops many is telling you something,
which is why this warns rather than silently intersecting.

## The test, and why it is not a plain t-test

The per-fold differences go through
[`corrected_paired_test()`](https://camilleross.org/taupatch/reference/corrected_paired_test.md),
the same Nadeau and Bengio (2003) correction the covariate jackknife
uses, and for the same reason: any two cross-validation training sets
share most of their rows, so folds are not independent and an
uncorrected paired t-test finds significance that is not there.

Two-sided here, unlike the jackknife. Leaving a covariate out has a
direction worth testing against; asking which of two models is better
does not.

## What "detectable" means

The smallest true difference this comparison would have found
significant at `level`, with probability `power`, given the fold-to-fold
variability it actually saw:

\$\$d\_{min} = SE \times (t\_{1-\alpha/2, df} + t\_{power, df})\$\$

It is a property of **this** design — this many folds, these stations,
this much variance between folds — not a general statement about the
models. It says nothing about whether a smaller difference exists, only
that this study would probably have missed it.

## References

Nadeau C, Bengio Y (2003). Inference for the generalization error.
*Machine Learning* **52**(3), 239-281.
[doi:10.1023/A:1024068626366](https://doi.org/10.1023/A%3A1024068626366)
— the variance correction

Dietterich TG (1998). Approximate statistical tests for comparing
supervised classification learning algorithms. *Neural Computation*
**10**(7), 1895-1923.
[doi:10.1162/089976698300017197](https://doi.org/10.1162/089976698300017197)
— why comparing learning algorithms on shared folds needs one

Hoenig JM, Heisey DM (2001). The abuse of power: the pervasive fallacy
of power calculations for data analysis. *The American Statistician*
**55**(1), 19-24.
[doi:10.1198/000313001300339897](https://doi.org/10.1198/000313001300339897)
— why `detectable` is reported rather than the observed-power statistic
it is often confused with

## See also

[`power_curve()`](https://camilleross.org/taupatch/reference/power_curve.md)
for how the answer changes with more stations

## Examples

``` r
if (FALSE) { # \dontrun{
rf <- fit_patch_model(dat, within_config(config, type = "rf"))
gam <- fit_patch_model(dat, within_config(config, type = "gam"))

compare_runs(list(rf = rf, gam = gam))
} # }
```
