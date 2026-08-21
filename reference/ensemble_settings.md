# Multi-algorithm ensemble settings

Which model types a run fits and how their projections are combined.
This is `BIOMOD_EnsembleModeling()` from the pipeline this package
replaces: several algorithms on the same data, filtered on how well they
did, then averaged.

## Usage

``` r
ensemble_settings(config)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

`NULL` when off, otherwise a list with `types`, `rule`, `weight_by`,
`min_score`, `workers`, and `settings`

## Details

    model:
      type: ensemble             # or set the block below and leave type alone
      ensemble:
        types: [rf, brt, glm, gam]
        rule: weighted_mean      # or: mean, median, committee
        weight_by: tss           # or: roc_auc, pr_auc, equal
        min_score: 0.4           # members scoring below this are excluded
        workers: true            # true = cores - 1; a count; false = sequential
        settings:                # per-member overrides of the model block
          gam:
            method: REML
          brt:
            learn_rate: 0.01

## Two different things called an ensemble

This one combines over **algorithms**, and its spread is disagreement
about the shape of the relationship — a forest and a logistic regression
looking at the same shelf and drawing different maps.

`projection.uncertainty` (see
[`uncertainty_settings()`](https://camilleross.org/taupatch/reference/uncertainty_settings.md))
combines over **resamples of the data** within one algorithm, and its
spread is how much the fit moves when the stations move.

They are independent and can both be on. When they are, each member
carries its own resample interval and the ensemble reports algorithm
disagreement on top of it, in separate columns — `algorithm_sd` against
`suitability_sd`.

## Why filter members at all

An ensemble that averages in a model which cannot separate the classes
moves the answer toward noise. `min_score` is biomod2's
`metric.select.thresh` under a plainer name, and 0.4 on TSS is a low bar
deliberately: it is there to catch a member that failed to fit anything,
not to tune the ensemble by selecting its best members on their own
evaluation scores, which would be selection on the same numbers used to
report it.

## See also

[`fit_patch_ensemble()`](https://camilleross.org/taupatch/reference/fit_patch_ensemble.md),
which runs it, and
[`uncertainty_settings()`](https://camilleross.org/taupatch/reference/uncertainty_settings.md)
for the other kind of ensemble

## Examples

``` r
config <- load_config(
  system.file("configs/mock_test.yaml", package = "taupatch")
)
ensemble_settings(config)                        # NULL: off by default
#> NULL

config$model$type <- "ensemble"
ensemble_settings(config)$types
#> [1] "rf"  "brt" "glm" "gam"

config$model$ensemble <- list(types = c("rf", "glm"), rule = "median")
ensemble_settings(config)
#> $types
#> [1] "rf"  "glm"
#> 
#> $rule
#> [1] "median"
#> 
#> $weight_by
#> [1] "tss"
#> 
#> $min_score
#> [1] 0.4
#> 
#> $workers
#> NULL
#> 
#> $settings
#> list()
#> 
```
