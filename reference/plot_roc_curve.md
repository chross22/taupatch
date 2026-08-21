# Plot cross-validated ROC curves

Draws one curve per resampling fold plus the pooled curve across all of
them.

## Usage

``` r
plot_roc_curve(predictions, path = NULL)
```

## Arguments

- predictions:

  the `predictions` element of a
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)
  result

- path:

  where to write a PNG; `NULL` returns the plot instead

## Value

the plot object, or `path` invisibly when written to disk

## Details

Per-fold curves are shown rather than only the pooled one because they
carry information the summary AUC hides: a model whose folds agree
closely is a different proposition from one averaging the same AUC out
of wildly varying folds, and the second is not trustworthy at a single
station even though both report the same number.

The curves come from held-out predictions, so they describe performance
on data the model did not see. A curve drawn on training data would sit
much closer to the corner and mean nothing.

## Examples

``` r
if (FALSE) { # \dontrun{
result <- run_taupatch("inst/configs/mock_test.yaml")
plot_roc_curve(result$model$predictions)
} # }
```
