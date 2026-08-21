# Attach bootstrap bounds to the evaluation table

Matched on the metric and on which cutoff it belongs to, rather than on
row order, so a metric appearing at both cutoffs gets the right pair
each time.

## Usage

``` r
merge_bootstrap_bounds(out, bounds)
```

## Arguments

- out:

  the assembled evaluation table

- bounds:

  the result of
  [`bootstrap_evaluation()`](https://camilleross.org/taupatch/reference/bootstrap_evaluation.md)

## Value

`out` with `lower` and `upper` columns
