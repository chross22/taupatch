# Covariate transformations available in the recipe

Which transformation a covariate needs is a modeling choice, so it is
config rather than code. The original applied `log(abs(x))` to a
hardcoded trio of chlorophyll, integrated chlorophyll, and bathymetry
(`original/buildZoopModel.R:134-136`).

## Usage

``` r
covariate_transforms()
```

## Value

a named list, one entry per transform, each with `label`, `description`,
`folds_sign`, `undefined_at_zero`, and either `fn` (applied directly) or
`step` (a `recipes` step function)

## Details

Two properties decide what a transform can safely be given:

- `folds_sign` marks the transforms that take `abs(x)` first, because
  they are undefined for negative input. That is right for a magnitude
  stored with a sign convention — bathymetry is negative depth — and
  wrong for a genuinely signed covariate, where it maps `-2` and `2`
  onto the same value. Derived covariates make the second case common: a
  temporal gradient, a vertical gradient, and the current components are
  all signed. A transform warns when the column it is given actually
  holds both signs.

- `undefined_at_zero` marks `log` and `log10`, which return `-Inf`
  there. Zeros are ordinary in chlorophyll and in any derived integral
  that starts at zero, so this is checked against the data rather than
  trusted.

`boxcox` and `yeojohnson` estimate their parameter from the data instead
of applying a fixed function, so they are recipe steps rather than a
function of `x`. Box-Cox requires strictly positive input; Yeo-Johnson
does not, which makes it the one estimated option that suits a signed
covariate.

## References

Box GEP, Cox DR (1964). An analysis of transformations. *Journal of the
Royal Statistical Society: Series B* **26**(2), 211-252.
[doi:10.1111/j.2517-6161.1964.tb00553.x](https://doi.org/10.1111/j.2517-6161.1964.tb00553.x)
— `boxcox`

Yeo I-K, Johnson RA (2000). A new family of power transformations to
improve normality or symmetry. *Biometrika* **87**(4), 954-959.
[doi:10.1093/biomet/87.4.954](https://doi.org/10.1093/biomet/87.4.954) —
`yeojohnson`

Field JG, Clarke KR, Warwick RM (1982). A practical strategy for
analysing multispecies distribution patterns. *Marine Ecology Progress
Series* **8**, 37-52.
[doi:10.3354/meps008037](https://doi.org/10.3354/meps008037) — the
fourth root as the plankton standard

## Examples

``` r
names(covariate_transforms())
#> [1] "log1p"       "log"         "log10"       "sqrt"        "fourth_root"
#> [6] "boxcox"      "yeojohnson" 
covariate_transforms()$log1p$description
#> [1] "The default, and what `log_transform` has always meant here. Defined at zero, unlike log and log10, which is why it is the one to reach for on chlorophyll and on integrals that start at zero."
```
