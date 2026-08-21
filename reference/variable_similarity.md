# Similarity of values to a training distribution, for one predictor

The per-variable half of
[`novelty_surface()`](https://camilleross.org/taupatch/reference/novelty_surface.md).
Negative below the training minimum and above its maximum, scaled by the
training range; inside, twice the distance to the nearer tail in
percentile terms, so the median scores 100.

## Usage

``` r
variable_similarity(values, train)
```

## Arguments

- values:

  the values to score

- train:

  the training values for the same predictor

## Value

a numeric vector the length of `values`
