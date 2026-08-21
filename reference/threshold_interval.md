# The bootstrap interval on the classification cutoff

Pulled out of the bounds table because it is not a metric and does not
belong in `evals.csv`, but it is the number to check before binarising a
projection: a cutoff that moves from 0.05 to 0.20 across resamples makes
a very different map at each end.

## Usage

``` r
threshold_interval(bounds)
```

## Arguments

- bounds:

  the result of
  [`bootstrap_evaluation()`](https://camilleross.org/taupatch/reference/bootstrap_evaluation.md)

## Value

`c(lower, upper)`, or `NULL` when the bootstrap did not run
