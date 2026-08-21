# Predict an ensemble across a covariate grid

Every qualifying member predicts every cell, and the four rules plus the
spread come out of the same matrix. The `suitability` layer is whichever
rule `model.ensemble.rule` names; the rest go beside it, so a run can be
read against a different rule without refitting anything.

## Usage

``` r
predict_grid_ensemble(ensemble, grid, uncertainty = NULL)
```

## Arguments

- ensemble:

  a `taupatch_ensemble` from
  [`fit_patch_ensemble()`](https://camilleross.org/taupatch/reference/fit_patch_ensemble.md)

- grid:

  a covariate grid from
  [`covariate_grid()`](https://camilleross.org/taupatch/reference/covariate_grid.md)

- uncertainty:

  settings from
  [`uncertainty_settings()`](https://camilleross.org/taupatch/reference/uncertainty_settings.md),
  or `NULL`

## Value

a tibble of `lon`, `lat`, `suitability`, the other rules, the algorithm
spread, and the per-member surfaces; `NULL` if no complete rows

## Details

`algorithm_sd` is the one to look at. It is disagreement between
algorithms on the same cell, which is a different question from
`suitability_sd` — the spread of one algorithm refitted on resampled
stations — and a different one again from `novelty`. A cell can be quiet
on one and loud on another.
