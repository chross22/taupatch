# How far outside the training data each cell sits

The multivariate environmental similarity surface of Elith, Kearney and
Phillips (2010). For each predictor it asks where a cell's value falls
in the distribution of values the model was trained on, and the cell
takes the worst answer across predictors — one predictor far outside its
training range is enough to make a prediction an extrapolation, however
ordinary the rest look.

## Usage

``` r
novelty_surface(grid, model_data, predictors)
```

## Arguments

- grid:

  the cells to score, with one column per predictor

- model_data:

  the data the model was fitted on

- predictors:

  predictor column names

## Value

a data frame of `novelty` and `novel_variable`, one row per cell

## Details

The scale runs to 100 and is readable directly:

- **100** — at the median of the training data for every predictor.

- **0 to 100** — inside the training range on all predictors; lower
  means nearer an edge of it.

- **below 0** — outside the training range on at least one predictor.
  The magnitude is how far outside, as a percentage of the training
  range, so `-50` is half a range beyond the edge. **These cells are
  extrapolation**, and the model has no evidence for what it says there.

`novel_variable` names the predictor responsible, which is the
actionable half: "this coast is extrapolated" is a shrug, and "this
coast is extrapolated because its chlorophyll is higher than anything a
station saw" is a decision about whether to widen the training window or
clip the map.

## References

Elith J, Kearney M, Phillips S (2010). The art of modelling
range-shifting species. *Methods in Ecology and Evolution* **1**(4),
330-342.
[doi:10.1111/j.2041-210X.2010.00036.x](https://doi.org/10.1111/j.2041-210X.2010.00036.x)

## See also

[`ensemble_spread()`](https://camilleross.org/taupatch/reference/ensemble_spread.md),
which answers a different question about the same cell

## Examples

``` r
train <- data.frame(SST = c(4, 8, 12, 16), CHL = c(0.2, 0.5, 1.0, 2.0))
grid <- data.frame(SST = c(10, 25), CHL = c(0.6, 0.6))

# The second cell is warmer than any training station, and says so.
novelty_surface(grid, train, c("SST", "CHL"))
#>   novelty novel_variable
#> 1     100            SST
#> 2     -75            SST
```
