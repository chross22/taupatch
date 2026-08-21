# Run the full taupatch pipeline

Loads a config and runs every stage in order: read zooplankton stations,
fetch and attach environmental covariates, label high-abundance patches
against the species threshold, fit the model, and project monthly
habitat suitability maps.

## Usage

``` r
run_taupatch(config_path, project = TRUE, keep_covariates = 50000)
```

## Arguments

- config_path:

  path to a config YAML file, or an already-loaded config list

- project:

  whether to produce monthly projections after fitting

- keep_covariates:

  the most covariate grid cells to return for mapping; `0` returns none.
  See
  [`thin_covariates()`](https://camilleross.org/taupatch/reference/thin_covariates.md)
  for what is kept and why.

## Value

a list with `config` (as the run actually used it, so a jackknife that
dropped a covariate shows in `covariates.exclude`), `data` (the labeled
modeling data), `model` (a
[`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)
result, or a
[`fit_patch_ensemble()`](https://camilleross.org/taupatch/reference/fit_patch_ensemble.md)
one), `projections` (or `NULL` if skipped), `jackknife` (or `NULL` if
not run), `covariate_means`, and `covariates` (a thinned grid, for
mapping)

## Details

Two optional stages sit between labelling and fitting, both off by
default and both turned on from the config:

- `covariates.jackknife` tests each covariate by leaving it out — see
  [`jackknife_settings()`](https://camilleross.org/taupatch/reference/jackknife_settings.md).
  It runs before the fit so its answer can change which covariates the
  model gets, and it only removes any if `jackknife.drop` says so.

- `model.ensemble` fits several algorithms instead of one and combines
  them — see
  [`ensemble_settings()`](https://camilleross.org/taupatch/reference/ensemble_settings.md).
  Everything after the fit works the same either way, so a config that
  turns this on gets ensemble projections without changing anything
  else.

## Examples

``` r
if (FALSE) { # \dontrun{
result <- run_taupatch(system.file("configs/mock_test.yaml", package = "taupatch"))
result$model$metrics
result$projections
} # }
```
