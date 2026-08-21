# The TSS-maximising cutoff, computed directly

The arithmetic behind
[`optimal_threshold()`](https://camilleross.org/taupatch/reference/optimal_threshold.md),
without building an ROC curve as a data frame to do it — the bootstrap
runs this a few thousand times, and the tibble was most of the cost. The
reported cutoff and the bootstrapped ones go through here alike, so they
cannot come to mean different things.

## Usage

``` r
best_cutoff(is_patch, probability)
```

## Arguments

- is_patch:

  logical, whether each observation is a patch

- probability:

  predicted probability of a patch

## Value

the TSS-maximising cutoff, or `NA_real_`
