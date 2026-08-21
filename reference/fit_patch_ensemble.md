# Fit an ensemble of model types on the same data

Fits every type in `model.ensemble.types` on the same stations, the same
predictors and the same cross-validation folds, then combines them. The
result is a drop-in for a
[`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)
object: it carries an `evaluation` table, a `classification_threshold`,
an `importance` table and a set of `predictors`, and
[`project_patch_model()`](https://camilleross.org/taupatch/reference/project_patch_model.md)
will project it.

## Usage

``` r
fit_patch_ensemble(dat, config, settings = ensemble_settings(config))
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
  [`ensemble_settings()`](https://camilleross.org/taupatch/reference/ensemble_settings.md)

## Value

an object of class `taupatch_ensemble`: a list with `members` (the
per-type
[`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)
results), `summary` (one row per type, with its score, weight and
whether it qualified), `predictions` (combined out-of-fold),
`evaluation`, `classification_threshold`,
`classification_threshold_interval`, `importance` (weighted across
members), `metrics`, `rule`, `predictors`, `model_data`, `threshold`,
and `type`, which is `"ensemble"`

## Why an ensemble at all

The four types disagree in ways that are informative rather than
incidental. A random forest and a GLM that rank the same stations mean
the relationships are close to monotonic; a sharp disagreement means
either a genuine non-linearity or a forest fitting noise, and there is
no way to tell which from one model. Averaging them is the practical
answer to not knowing which is right, and the `algorithm_sd` surface a
projection then carries is the map of where that choice actually
mattered.

## How the ensemble gets an honest evaluation

Every member is fitted on the same folds, drawn from the same
`model.seed`, so the held-out predictions line up row for row. The
ensemble's own out-of-fold predictions are therefore built by combining
members on the rows none of them saw, and the reported evaluation, the
TSS-optimal cutoff and its bootstrap interval all come from those — the
same functions, on the same footing, as a single model's.

This matters because the obvious alternative is wrong. Averaging the
members' evaluation scores would report the ensemble as the average of
its parts, which is not what an ensemble does: combining uncorrelated
members usually beats all of them, and combining correlated ones does
not, and only a cross-validated ensemble prediction can tell those
apart.

## A member that fails

A type whose package is not installed, or that will not fit these data,
is dropped with a warning rather than failing the run — an ensemble of
three is still an ensemble. Two members is the floor; below that the run
stops, since one algorithm averaged with nothing is a single model
wearing a different object.

## References

Araújo MB, New M (2007). Ensemble forecasting of species distributions.
*Trends in Ecology & Evolution* **22**(1), 42-47.
[doi:10.1016/j.tree.2006.09.010](https://doi.org/10.1016/j.tree.2006.09.010)

Thuiller W, Lafourcade B, Engler R, Araújo MB (2009). BIOMOD - a
platform for ensemble forecasting of species distributions. *Ecography*
**32**(3), 369-373.
[doi:10.1111/j.1600-0587.2008.05742.x](https://doi.org/10.1111/j.1600-0587.2008.05742.x)
— what this replaces

## See also

[`ensemble_settings()`](https://camilleross.org/taupatch/reference/ensemble_settings.md)
for the config block,
[`ensemble_rules()`](https://camilleross.org/taupatch/reference/ensemble_rules.md)
for the combination rules,
[`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)
for a single member

## Examples

``` r
if (FALSE) { # \dontrun{
config <- load_config("my_run.yaml")
config$model$type <- "ensemble"
ensemble <- fit_patch_ensemble(dat, config)
ensemble$summary
ensemble$evaluation
} # }
```
