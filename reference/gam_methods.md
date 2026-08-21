# Smoothing parameter estimation methods mgcv offers

`GCV.Cp` is mgcv's default and what the package has always used. `REML`
and `ML` are the ones to reach for when a smooth looks overfitted:
generalized cross-validation is known to undersmooth, and REML resists
it.

## Usage

``` r
gam_methods()
```

## Value

character vector of method names

## References

Wood SN (2011). Fast stable restricted maximum likelihood and marginal
likelihood estimation of semiparametric generalized linear models.
*Journal of the Royal Statistical Society: Series B* **73**(1), 3-36.
[doi:10.1111/j.1467-9868.2010.00749.x](https://doi.org/10.1111/j.1467-9868.2010.00749.x)

## Examples

``` r
gam_methods()
#> [1] "GCV.Cp" "REML"   "ML"     "P-REML" "P-ML"  
```
