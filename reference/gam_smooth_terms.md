# Smooth terms of a fitted GAM

What a GAM has that the others do not: a per-term statement of how
non-linear the fitted relationship actually is. `edf` is the effective
degrees of freedom — 1 means the smooth collapsed to a straight line and
the flexibility bought nothing, and larger values mean a genuinely
bending relationship.

## Usage

``` r
gam_smooth_terms(fitted)
```

## Arguments

- fitted:

  a fitted
  [`workflows::workflow()`](https://workflows.tidymodels.org/reference/workflow.html)
  whose model is an `mgcv` GAM

## Value

a data frame of `term`, `edf`, `statistic`, and `p_value`, most
non-linear first

## Examples

``` r
if (FALSE) { # \dontrun{
gam_smooth_terms(model$workflow)
} # }
```
