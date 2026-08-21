# The power a design has against a stated difference

The complement of
[`minimum_detectable()`](https://camilleross.org/taupatch/reference/minimum_detectable.md):
given how variable the folds were, how often would a true difference of
`difference` be called significant?

## Usage

``` r
achieved_power(difference, std_err, df, level = 0.95)
```

## Arguments

- difference:

  the true difference to detect

- std_err:

  the corrected standard error of the difference

- df:

  degrees of freedom

- level:

  confidence level

## Value

a probability, or `NA_real_`
