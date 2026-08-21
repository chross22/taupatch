# Spread of an ensemble's predictions, per cell

Every member predicts every cell; this reduces those to a standard
deviation and an interval. The point estimate is left alone — it stays
the prediction of the model fitted on all the data, so turning
uncertainty on adds columns to a map without moving it.

## Usage

``` r
ensemble_spread(ensemble, newdata, level = 0.9)
```

## Arguments

- ensemble:

  a list of fitted workflows, from
  [`projection_ensemble()`](https://camilleross.org/taupatch/reference/projection_ensemble.md)

- newdata:

  the cells to predict

- level:

  interval width, e.g. 0.9 for a 5th-to-95th percentile range

## Value

a data frame of `suitability_sd`, `suitability_lower`,
`suitability_upper`, and `n_members`; `NULL` if the ensemble is empty

## What it does not cover

This is the spread of refits on resampled training data. It is a **lower
bound** on how wrong a cell can be, and three things are outside it
entirely: covariates that are themselves estimates carrying their own
error, the possibility that the model form is wrong, and extrapolation.
The last is the one that bites, because agreement between members is not
evidence: they were all trained on the same data and can walk off the
end of it together.
[`novelty_surface()`](https://camilleross.org/taupatch/reference/novelty_surface.md)
is reported beside this rather than instead of it for that reason.

## Reading the interval

It is a percentile range over the members, not a calibrated confidence
interval, and with the default `folds` method there are only
`model.cv_folds` of them. Ten members cannot support a 95% interval —
its 2.5th percentile is the smallest of the ten — which is why `level`
defaults to 0.9 and why `method: bootstrap` exists for when the number
needs to mean something.

The point estimate is not guaranteed to fall inside it. The estimate
comes from the model fitted on all the data and the interval from models
fitted on parts of it, so these are two different quantities; on the
package's mock run a 90% interval contains the point estimate for about
90% of cells, which is the behaviour to expect rather than a fault.

## See also

[`novelty_surface()`](https://camilleross.org/taupatch/reference/novelty_surface.md),
which answers the question this one cannot
