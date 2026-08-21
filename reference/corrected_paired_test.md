# A paired test across folds, with the Nadeau-Bengio variance correction

The naive paired t-test over `k` cross-validation folds pretends the
folds are independent. They share all but one fold's worth of training
data, so its variance estimate is far too small and it finds
significance everywhere. This inflates the variance by `1/k + 1/(k-1)` —
the second term being the ratio of test-set to training-set size in
k-fold — which is the standard correction and costs roughly a factor of
`sqrt(2)` off the statistic.

## Usage

``` r
corrected_paired_test(differences, alternative = c("greater", "two.sided"))
```

## Arguments

- differences:

  per-fold score of the full model minus the reduced one

- alternative:

  `"greater"` for a directional hypothesis, `"two.sided"` when either
  sign is a finding

## Value

a list of `estimate`, `std_err`, `statistic`, `df`, `p_value`, `n`

## Details

The default is one-sided, because the jackknife's hypothesis is
directional: the question is whether removing the covariate makes the
model *worse*, and a covariate whose removal improves the model has
failed the test rather than passed a different one. Comparing two models
is not directional in that way - either may be the better - so
[`compare_runs()`](https://camilleross.org/taupatch/reference/compare_runs.md)
asks for `two.sided`.

## References

Nadeau C, Bengio Y (2003). Inference for the generalization error.
*Machine Learning* **52**(3), 239-281.
[doi:10.1023/A:1024068626366](https://doi.org/10.1023/A%3A1024068626366)

Bouckaert RR, Frank E (2004). Evaluating the replicability of
significance tests for comparing learning algorithms. *Advances in
Knowledge Discovery and Data Mining* (PAKDD 2004), Lecture Notes in
Computer Science 3056, 3-12. Springer. — the correction applied to
k-fold specifically. Cited without its DOI deliberately: it is a
Springer chapter, so the identifier contains an underscore, and the
citation checker's DOI pattern treats one as a terminator.
