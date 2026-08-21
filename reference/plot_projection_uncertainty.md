# Plot how far a monthly projection can be trusted

The companion to
[`plot_projection()`](https://camilleross.org/taupatch/reference/plot_projection.md):
the same cells, panelled by what is uncertain about them rather than by
what is predicted. Whichever of the uncertainty surfaces the run
produced are drawn, and nothing else.

## Usage

``` r
plot_projection_uncertainty(predicted, year, month, species, path)
```

## Arguments

- predicted:

  a projection from
  [`predict_grid()`](https://camilleross.org/taupatch/reference/predict_grid.md)
  with uncertainty columns

- year:

  year being projected

- month:

  month being projected

- species:

  species name, for the title

- path:

  where to write the PNG

## Value

`path` invisibly, or `NULL` when there is nothing to draw

## Details

The two panels are deliberately not merged into a single "confidence"
layer. They measure different things and are free to disagree in either
direction, and the disagreement is the informative part: a cell can be
stable across every member and still be extrapolated, because agreement
between members trained on the same data is not evidence about ground
the data never covered. Blending the two would average that case away
instead of showing it.

Diverging colour on the novelty panel, centred at zero, because zero is
the meaningful break: above it the model is interpolating, below it the
cell is outside the training range on some predictor and the model has
no evidence for what it says there.

## See also

[`novelty_surface()`](https://camilleross.org/taupatch/reference/novelty_surface.md)
for how the novelty panel is computed
