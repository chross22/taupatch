# Covariate jackknife settings

Whether a run tests its covariates before fitting, and what it does with
the answer. Off by default: it costs `2 * predictors + 1`
cross-validations, which is minutes on a station table and worth paying
deliberately rather than on every iteration.

## Usage

``` r
jackknife_settings(config)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

`NULL` when off, otherwise a list with `metric`, `criterion`, `alpha`,
`adjust`, `drop`, `keep`, `min_predictors`, and `workers`

## Details

    covariates:
      jackknife: true            # or the block below, for the non-defaults
      jackknife:
        metric: roc_auc          # or: pr_auc
        criterion: fold          # or: parametric  (glm and gam only)
        alpha: 0.05
        adjust: holm             # or: BH, bonferroni, none
        drop: false              # DEFAULT: report, never drop on its own
        keep: [DEPTH, jday]      # never dropped, whatever the test says
        min_predictors: 2        # never drop below this many
        workers: true            # true = cores - 1; a count; false = sequential

## Dropping is opt-in, and that is deliberate

`drop` defaults to `false`, so the default behaviour is a table and a
message. A covariate that fails this test is one the *other covariates
already account for* on these stations — which is a statement about
collinearity in this sample at least as much as about ecology. Bottom
depth and sea surface temperature carry much of the same information on
a shelf; the test will happily declare either one redundant depending on
which the model reached for first, and dropping it silently would make
the map look better while removing the variable a reader would have
asked about.

`keep` is the escape hatch for exactly that: a covariate that is in the
model because the study is about it stays in the model.

## See also

[`jackknife_covariates()`](https://camilleross.org/taupatch/reference/jackknife_covariates.md),
which runs it

## Examples

``` r
config <- load_config(
  system.file("configs/mock_test.yaml", package = "taupatch")
)
jackknife_settings(config)                       # NULL: off by default
#> NULL

config$covariates$jackknife <- TRUE
jackknife_settings(config)                       # drop is FALSE
#> $metric
#> [1] "roc_auc"
#> 
#> $criterion
#> [1] "fold"
#> 
#> $alpha
#> [1] 0.05
#> 
#> $adjust
#> [1] "holm"
#> 
#> $drop
#> [1] FALSE
#> 
#> $keep
#> character(0)
#> 
#> $min_predictors
#> [1] 2
#> 
#> $workers
#> NULL
#> 
#> $type
#> NULL
#> 

config$covariates$jackknife <- list(drop = TRUE, keep = "jday")
jackknife_settings(config)
#> $metric
#> [1] "roc_auc"
#> 
#> $criterion
#> [1] "fold"
#> 
#> $alpha
#> [1] 0.05
#> 
#> $adjust
#> [1] "holm"
#> 
#> $drop
#> [1] TRUE
#> 
#> $keep
#> [1] "jday"
#> 
#> $min_predictors
#> [1] 2
#> 
#> $workers
#> NULL
#> 
#> $type
#> NULL
#> 
```
