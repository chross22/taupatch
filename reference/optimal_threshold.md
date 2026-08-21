# Probability cutoff that maximises TSS

The metrics table reports sensitivity and specificity at the default 0.5
cutoff, which is rarely right when the classes are imbalanced — and they
are here by construction, since a 90th-percentile abundance threshold
makes only 10% of stations patches. At 0.5 a random forest will call
almost nothing a patch, so sensitivity looks far worse than the model
can actually achieve.

## Usage

``` r
optimal_threshold(predictions)
```

## Arguments

- predictions:

  held-out predictions from resampling

## Value

the TSS-maximising cutoff, or `NA_real_` if it cannot be computed

## Details

This is the cutoff the original pipeline was reaching for with
`metric.binary = 'ROC'` when it binarised its projections.

## References

Allouche O, Tsoar A, Kadmon R (2006). Assessing the accuracy of species
distribution models: prevalence, kappa and the true skill statistic
(TSS). *Journal of Applied Ecology* **43**(6), 1223-1232.
[doi:10.1111/j.1365-2664.2006.01214.x](https://doi.org/10.1111/j.1365-2664.2006.01214.x)
