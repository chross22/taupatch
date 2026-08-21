# Pull each predictor's approximate p-value out of a fitted GAM

A predictor enters the formula either as a smooth or, when it had too
few distinct values for one, as a linear term — see
[`model_formula()`](https://camilleross.org/taupatch/reference/model_formula.md)
— so its p-value is in the smooth table for some predictors and the
parametric table for others. Both are looked in, keyed on the term name
rather than on position.

## Usage

``` r
gam_term_p_values(fit, predictors)
```

## Arguments

- fit:

  a fitted [`mgcv::gam`](https://rdrr.io/pkg/mgcv/man/gam.html)

- predictors:

  predictor column names

## Value

a numeric vector of p-values, one per predictor
