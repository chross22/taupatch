# Partial effect of each predictor on patch probability

How predicted patch probability moves as one predictor is swept across
its range, with every other predictor held at the values it actually
takes. This is a partial dependence curve: for each value on the sweep,
the predictor is set to that value for every station, the model is asked
for a probability, and those are averaged.

## Usage

``` r
partial_effects(fitted, model_data, predictors, grid_size = 20, max_rows = 500)
```

## Arguments

- fitted:

  a fitted
  [`workflows::workflow()`](https://workflows.tidymodels.org/reference/workflow.html)

- model_data:

  the data it was fitted on

- predictors:

  predictor column names

- grid_size:

  how many points to sweep each predictor across

- max_rows:

  stations to average over; the full set when smaller

## Value

a data frame with `variable`, `value`, and `probability`

## Details

Importance says a predictor matters; this says what it does — whether
probability rises, falls, peaks in the middle, or bends somewhere
particular. That is most of what a habitat model is fitted to find out.

Computed by prediction rather than read out of the fitted object, so it
means the same thing for all four model types and the curves can be laid
against each other. A GAM's own smooths are the exact version of this
for a GAM alone —
[`gam_smooth_terms()`](https://camilleross.org/taupatch/reference/gam_smooth_terms.md)
reports those — but they are on the log-odds scale and cannot be
compared with a forest.

## What it hides

Averaging over the other predictors is what makes one curve per
predictor possible, and it is also the limitation: an effect that
reverses depending on another predictor averages to something flatter
than either case, and the plot cannot show that it did. Two correlated
predictors are also swept into combinations the ocean never produces.

## References

Friedman JH (2001). Greedy function approximation: a gradient boosting
machine. *Annals of Statistics* **29**(5), 1189-1232.
[doi:10.1214/aos/1013203451](https://doi.org/10.1214/aos/1013203451) —
where partial dependence comes from, section 8.2

## See also

[`plot_partial_effects()`](https://camilleross.org/taupatch/reference/plot_partial_effects.md)

## Examples

``` r
if (FALSE) { # \dontrun{
effects <- partial_effects(model$workflow, model$model_data, model$predictors)
} # }
```
