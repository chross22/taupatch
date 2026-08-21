# Spline bases mgcv offers for a smooth

What shape the smooth is built from. `tp` is the default thin-plate
spline and suits almost everything. `ts` is the same with an extra
shrinkage penalty, so a term that earns nothing can be shrunk out of the
model altogether rather than left wiggling at one degree of freedom -
the per-smooth equivalent of `select_features`. `cr` is a cheaper cubic
regression spline, worth it on a large grid. `cc` is cyclic, which is
the one that matters here: day of year should join up at the end of
December rather than being free to jump.

## Usage

``` r
gam_bases()
```

## Value

character vector of basis codes

## References

Marra G, Wood SN (2011). Practical variable selection for generalized
additive models. *Computational Statistics & Data Analysis* **55**(7),
2372-2387.
[doi:10.1016/j.csda.2011.02.004](https://doi.org/10.1016/j.csda.2011.02.004)
— the shrinkage penalty behind `ts`, and behind `select_features`

Wood SN (2017). *Generalized Additive Models: An Introduction with R*,
2nd edition. Chapman and Hall/CRC.
[doi:10.1201/9781315370279](https://doi.org/10.1201/9781315370279) —
every basis listed here

## Examples

``` r
gam_bases()
#> [1] "tp" "ts" "cr" "cc" "ps" "ds" "gp"
```
