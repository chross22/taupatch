# Plot variable importance

Plot variable importance

## Usage

``` r
plot_importance(importance, path = NULL)
```

## Arguments

- importance:

  an importance tibble from
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)

- path:

  where to write the PNG; `NULL` returns the plot instead

## Value

the plot object, or `path` invisibly when written to disk
