# Plot logistic regression coefficients with their intervals

Plot logistic regression coefficients with their intervals

## Usage

``` r
plot_glm_coefficients(coefficients, path = NULL)
```

## Arguments

- coefficients:

  a data frame from
  [`glm_coefficients()`](https://camilleross.org/taupatch/reference/glm_coefficients.md)

- path:

  optional file to write the plot to instead of returning it

## Value

a `ggplot` object, or `path` invisibly when writing
