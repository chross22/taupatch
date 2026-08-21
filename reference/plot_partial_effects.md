# Plot partial effects, one panel per predictor

Plot partial effects, one panel per predictor

## Usage

``` r
plot_partial_effects(effects, path = NULL)
```

## Arguments

- effects:

  a data frame from
  [`partial_effects()`](https://camilleross.org/taupatch/reference/partial_effects.md)

- path:

  optional file to write the plot to instead of returning it

## Value

a `ggplot` object, or `path` invisibly when writing

## Examples

``` r
if (FALSE) { # \dontrun{
plot_partial_effects(partial_effects(model$workflow, model$model_data,
                                     model$predictors))
} # }
```
