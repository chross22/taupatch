# Coefficients of a fitted logistic regression

What a GLM has that the others do not: a signed, testable number per
predictor. Because the recipe centres and scales, these are on a common
scale and can be read against each other — a coefficient of 0.8 moves
the log-odds by 0.8 per standard deviation of its predictor.

## Usage

``` r
glm_coefficients(fitted)
```

## Arguments

- fitted:

  a fitted
  [`workflows::workflow()`](https://workflows.tidymodels.org/reference/workflow.html)
  whose model is a `glm`

## Value

a data frame of `variable`, `estimate`, `std_error`, `statistic`,
`p_value`, and the 95% interval as `lower`/`upper`

## Examples

``` r
if (FALSE) { # \dontrun{
glm_coefficients(model$workflow)
} # }
```
