# An AUC that returns NA rather than erroring on a degenerate resample

An AUC that returns NA rather than erroring on a degenerate resample

## Usage

``` r
safe_auc(fn, truth, probability)
```

## Arguments

- fn:

  a `yardstick` `*_vec` function

- truth:

  the outcome factor

- probability:

  predicted probability of the event

## Value

the metric, or `NA_real_`
