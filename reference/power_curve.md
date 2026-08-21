# How the comparison would improve with more stations

[`compare_runs()`](https://camilleross.org/taupatch/reference/compare_runs.md)
answers what this survey could see. This answers what a larger one
would: it refits both runs on subsamples of the stations, at several
sizes, and traces how the power to detect a difference grows with `n`.

## Usage

``` r
power_curve(
  dat,
  configs,
  fractions = c(0.25, 0.5, 0.75, 1),
  replicates = 5,
  difference = NULL,
  metric = "roc_auc",
  level = 0.95,
  workers = NULL,
  seed = 42
)
```

## Arguments

- dat:

  labeled modeling data from
  [`label_patch()`](https://camilleross.org/taupatch/reference/label_patch.md)
  with covariates attached

- configs:

  a named list of two or more configs to compare. The first is the
  reference; each is fitted exactly as its own run would be.

- fractions:

  the shares of the stations to fit at

- replicates:

  how many subsamples per fraction; the spread across them is what stops
  one unlucky draw from setting a point on the curve

- difference:

  the true difference to compute power against; `NULL` uses the one
  observed at the largest fraction

- metric:

  `"roc_auc"` or `"pr_auc"`

- level:

  confidence level the test would use

- workers:

  how many workers; see
  [`resolve_workers()`](https://camilleross.org/taupatch/reference/resolve_workers.md)

- seed:

  a seed, so a curve is reproducible

## Value

a data frame with one row per fraction: `fraction`, `n_stations`,
`replicates`, `difference` (mean observed), `std_err`, `df`, `power`,
and `detectable`. The target difference is on it as a `difference`
attribute.

## Details

The curve is the useful artefact rather than any single number on it.
Power against sample size is steeply non-linear, and where a study sits
on that curve decides what the next survey is worth: a comparison at
0.35 power is one more season away from being decisive, and one at 0.9
will not be improved by more stations because it is already there.

## What it costs, and what it therefore skips

`fractions × replicates × runs` cross-validations. Everything is
refitted at every size — the point is precisely that a model trained on
half the stations is a different model, not the same model evaluated on
fewer — so this is the expensive function in the package and
parallelises over the whole grid.

It goes through the same fold-scoring path the covariate jackknife uses,
which fits and scores and stops there. No bootstrap intervals, no
variable importance, no projection: none of it enters the curve, and all
of it would be paid for at every point.

## Subsampling stations, not folds

Rows are drawn without replacement, and the folds are then built inside
each subsample. Reusing the full run's folds and thinning them would
shrink the held-out sets while leaving the training sets nearly whole,
which measures something else entirely — the curve has to come from
models that were actually trained on less.

Both runs see the **same** subsample and the **same** folds at every
point, which is what keeps the comparison paired all the way down the
curve.

## Reading it honestly

The target difference defaults to the one observed on the full data, and
that is an estimate, not a truth. If the observed gap is itself mostly
noise, the curve answers "how many stations to reliably detect a
difference this size" for a size that may not be real. It is a
projection under an assumption, and the assumption is the observed
effect.

## References

Nadeau C, Bengio Y (2003). Inference for the generalization error.
*Machine Learning* **52**(3), 239-281.
[doi:10.1023/A:1024068626366](https://doi.org/10.1023/A%3A1024068626366)

## See also

[`compare_runs()`](https://camilleross.org/taupatch/reference/compare_runs.md),
which answers the same question for the data you already have

## Examples

``` r
if (FALSE) { # \dontrun{
rf <- config; rf$model$type <- "rf"
gam <- config; gam$model$type <- "gam"

curve <- power_curve(dat, list(rf = rf, gam = gam))
curve[c("n_stations", "power", "detectable")]
} # }
```
