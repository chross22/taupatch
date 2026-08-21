# Write an ensemble's own artifacts

What a single model has no equivalent of: which algorithms were fitted,
how each scored, what weight it was given, and whether it qualified.
This is the first thing to read after an ensemble run — a table showing
one member at 0.9 weight and three near zero is a single model with
extra steps, and only this file says so.

## Usage

``` r
write_ensemble_outputs(model, out)
```

## Arguments

- model:

  a `taupatch_ensemble` from
  [`fit_patch_ensemble()`](https://camilleross.org/taupatch/reference/fit_patch_ensemble.md)

- out:

  the run's output directory

## Value

`NULL`, invisibly
