# Test every covariate by leaving it out, in parallel

The jackknife of Elith et al. (2011): refit the model without each
covariate in turn, and see how much worse it ranks stations. A covariate
whose removal costs nothing is one the others already account for.
Alongside it goes the other half of the classical jackknife — the model
fitted on that covariate *alone* — because the two answer different
questions and the pair is what makes the table readable:

## Usage

``` r
jackknife_covariates(dat, config, settings = NULL)
```

## Arguments

- dat:

  labeled modeling data from
  [`label_patch()`](https://camilleross.org/taupatch/reference/label_patch.md)
  with covariates attached

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- settings:

  from
  [`jackknife_settings()`](https://camilleross.org/taupatch/reference/jackknife_settings.md);
  defaults are used when the config has no jackknife block, so this can
  be called on any config

## Value

a data frame with one row per covariate, ordered by `contribution`,
carrying `variable`, `metric`, `score_full`, `score_without`,
`score_only`, `contribution`, `contribution_se`, `statistic`, `df`,
`p_value`, `p_adjusted`, `parametric_p`, `parametric_test`,
`significant`, and `n_folds`. The full model's score is on it as a
`score_full` attribute.

## Details

- **`score_without`** is low when the covariate carries something no
  other covariate has. This is its *unique* contribution.

- **`score_only`** is high when the covariate carries a lot on its own,
  whether or not anything else carries it too.

A covariate can score high on one and nothing on the other, and that
combination is the informative one: high `score_only` with no unique
contribution means the information is real and duplicated, which is a
very different thing from a covariate that is simply uninformative.

Every refit uses **the same cross-validation folds as the main model**,
drawn from `model.seed`, so the comparison is paired fold by fold and
none of the difference is the split moving underneath it.

## What "significant" means here

The reported `p_value` is a one-sided test of whether leaving the
covariate out makes the model worse, computed from the per-fold
differences with the variance correction of Nadeau and Bengio (2003).

The correction is the load-bearing part. A plain paired t-test across
`k` folds treats the folds as independent, and they are not — any two
training sets share most of their rows — so its variance estimate is
badly optimistic and it declares far more covariates significant than it
should. There is no unbiased estimator of the variance of k-fold
cross-validation (Bengio and Grandvalet 2004); the correction inflates
the naive variance by `1/k + 1/(k-1)` instead, which is the standard
workable answer and roughly halves the t statistic.

`p_adjusted` then accounts for having asked the question once per
covariate, Holm by default.

## The parametric column

For a GLM and a GAM there is an exact-ish test of the same hypothesis,
and it is reported beside the fold test rather than instead of it:

- **`glm`** — the drop-in-deviance likelihood ratio test against the
  nested model, `parametric_test` reading `LRT`.

- **`gam`** — `mgcv`'s approximate p-value for the term,
  `parametric_test` reading `gam-approx`. It is approximate by
  construction: it does not account for the smoothing parameters having
  been estimated from the same data, so it runs anti-conservative (Wood
  2017, section 6.12).

A forest and a boosted tree have no likelihood, so these columns are
`NA` there. That is the whole reason the fold test is the default
criterion — it means the same thing for all four model types.

## Rows, not just columns

Every model here is fitted on the rows that are complete across **all**
predictors, including the ones being left out. Letting a reduced model
pick up the rows its dropped covariate was missing would compare two
models on two different datasets, and the reduced one would sometimes
win for that reason alone.

## References

Elith J, Phillips SJ, Hastie T, Dudík M, Chee YE, Yates CJ (2011). A
statistical explanation of MaxEnt for ecologists. *Diversity and
Distributions* **17**(1), 43-57.
[doi:10.1111/j.1472-4642.2010.00725.x](https://doi.org/10.1111/j.1472-4642.2010.00725.x)
— the leave-one-out / only-one pair this reports

Nadeau C, Bengio Y (2003). Inference for the generalization error.
*Machine Learning* **52**(3), 239-281.
[doi:10.1023/A:1024068626366](https://doi.org/10.1023/A%3A1024068626366)
— the variance correction

Bengio Y, Grandvalet Y (2004). No unbiased estimator of the variance of
k-fold cross-validation. *Journal of Machine Learning Research* **5**,
1089-1105. <https://jmlr.org/papers/v5/grandvalet04a.html> — why a
correction is needed rather than a better estimator

Dietterich TG (1998). Approximate statistical tests for comparing
supervised classification learning algorithms. *Neural Computation*
**10**(7), 1895-1923.
[doi:10.1162/089976698300017197](https://doi.org/10.1162/089976698300017197)
— the inflated Type I error of the uncorrected test

Wood SN (2017). *Generalized Additive Models: An Introduction with R*,
2nd edition. Chapman and Hall/CRC.
[doi:10.1201/9781315370279](https://doi.org/10.1201/9781315370279) — the
GAM term p-values and their caveat

## See also

[`jackknife_settings()`](https://camilleross.org/taupatch/reference/jackknife_settings.md)
for the config block,
[`jackknife_dropped()`](https://camilleross.org/taupatch/reference/jackknife_dropped.md)
for what `drop` would remove,
[`permutation_importance()`](https://camilleross.org/taupatch/reference/permutation_importance.md)
for the other answer to "which covariate matters"

## Examples

``` r
if (FALSE) { # \dontrun{
config <- load_config("my_run.yaml")
dat <- label_patch(attach_covariates(load_zoop_data(config),
                                     fetch_covariates(config), config), config)
jk <- jackknife_covariates(dat, config)
jk[c("variable", "contribution", "p_adjusted", "significant")]
} # }
```
