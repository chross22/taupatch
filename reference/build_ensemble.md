# Assemble the fitted members into an ensemble

Split from
[`fit_patch_ensemble()`](https://camilleross.org/taupatch/reference/fit_patch_ensemble.md)
so the scoring, weighting and combining can be tested on members built
any way at all, including hand-made ones.

## Usage

``` r
build_ensemble(members, config, settings)
```

## Arguments

- members:

  a named list of
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)
  results

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- settings:

  from
  [`ensemble_settings()`](https://camilleross.org/taupatch/reference/ensemble_settings.md)

## Value

a `taupatch_ensemble`
