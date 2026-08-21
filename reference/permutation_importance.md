# Permutation variable importance, for any model type

How much worse the model ranks stations when one predictor is shuffled:
the drop in ROC AUC, averaged over several shuffles. Zero means the
predictor carried nothing the others did not.

## Usage

``` r
permutation_importance(fitted, model_data, predictors, times = 5)
```

## Arguments

- fitted:

  a fitted
  [`workflows::workflow()`](https://workflows.tidymodels.org/reference/workflow.html)

- model_data:

  the data it was fitted on, including the `patch` column

- predictors:

  predictor column names

- times:

  how many shuffles to average over

## Value

a tibble of `variable` and `importance`, most important first

## Details

This replaces `ranger`'s built-in importance, which existed only because
the only model was a random forest. A GLM and a GAM have no such thing,
and the importances that engines do report are not comparable — ranger's
permutation drop and xgboost's split gain are different quantities on
different scales, so reading one against the other says nothing.
Computing it here means one definition for all four types, which is what
makes comparing them meaningful.

Measured on the training data, since the fitted workflow is what is
being interrogated. That inflates the absolute values for a model that
overfits, but the ranking — which is what the plot is read for — holds
up.

## References

Breiman L (2001). Random forests. *Machine Learning* **45**(1), 5-32.
[doi:10.1023/A:1010933404324](https://doi.org/10.1023/A%3A1010933404324)
— where permutation importance comes from

Fisher A, Rudin C, Dominici F (2019). All models are wrong, but many are
useful: learning a variable's importance by studying an entire class of
prediction models simultaneously. *Journal of Machine Learning Research*
**20**(177), 1-81. <https://jmlr.org/papers/v20/18-760.html> —
permutation importance as a model-agnostic quantity, which is what makes
one definition across four model types meaningful
