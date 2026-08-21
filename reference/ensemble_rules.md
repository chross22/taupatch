# Ways an ensemble can combine its members

`mean` and `weighted_mean` average the probabilities, the second in
proportion to how well each member scored. `median` averages them
robustly, which is the one to reach for when a single member is capable
of going badly wrong somewhere on the grid — a boosted tree
extrapolating, usually — since a mean lets that member drag a cell and a
median does not.

## Usage

``` r
ensemble_rules()
```

## Value

character vector of rule names

## Details

`committee` is different in kind, and is biomod2's committee averaging:
each member binarises its own prediction at its own TSS-optimal cutoff,
and the cell gets the fraction of members that called it a patch. So it
is already on a 0-to-1 scale and reads directly as agreement — 0.75
means three of four algorithms say patch — but it throws away how
*confident* each member was.

Every rule is computed and written on every run. `model.ensemble.rule`
picks which one is the `suitability` layer, and the others go beside it,
because the disagreement between rules is itself worth looking at and
recomputing them means refitting.

## References

Araújo MB, New M (2007). Ensemble forecasting of species distributions.
*Trends in Ecology & Evolution* **22**(1), 42-47.
[doi:10.1016/j.tree.2006.09.010](https://doi.org/10.1016/j.tree.2006.09.010)
— why an ensemble of algorithms rather than a chosen best one

Marmion M, Parviainen M, Luoto M, Heikkinen RK, Thuiller W (2009).
Evaluation of consensus methods in predictive species distribution
modelling. *Diversity and Distributions* **15**(1), 59-69.
[doi:10.1111/j.1472-4642.2008.00491.x](https://doi.org/10.1111/j.1472-4642.2008.00491.x)
— the rules compared against each other

## Examples

``` r
ensemble_rules()
#> [1] "mean"          "weighted_mean" "median"        "committee"    
```
