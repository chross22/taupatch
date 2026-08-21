# Derived covariates computed from the covariate grid

Covariates the pipeline computes rather than downloads: spatial and
temporal gradients, distances to fronts and contours, lags, integrals,
and flow diagnostics. The computation is
[derivoce](https://github.com/chross22/derivoce) throughout, which owns
the definitions so every consumer computes them identically; this
package supplies the config block naming which ones a run wants and
threads the results through the rest of the pipeline.

## Usage

``` r
derivoce_covariates()
```

## Value

a named list, one entry per supported step type, each with `label`,
`units`, `description`, `inputs`, `neighbourhood`, `required` (extra
fields with no default), and `outputs` (a function giving the column
names a step of that type produces)

## Details

Every entry describes one derivoce function that a `covariates.derivoce`
step can name. `inputs` gives the step fields that name covariate
columns, with their defaults: `""` marks a field the config must supply,
`NA` an optional one with no default. `neighbourhood` marks the steps
that read a point's surroundings rather than only its own value, which
is what makes upsampling matter (see
[`add_derivoce_covariates()`](https://camilleross.org/taupatch/reference/add_derivoce_covariates.md)).

## References

Each step implements a published method, and the citation belongs to
that method rather than to this package. derivoce's own help pages carry
the reference for each function, and its README collects them; the ones
behind the steps here that are not simply arithmetic on the grid:

Belkin IM, O'Reilly JE (2009). An algorithm for oceanic front detection
in chlorophyll and SST satellite imagery. *Journal of Marine Systems*
**78**(3), 319-326.
[doi:10.1016/j.jmarsys.2008.11.018](https://doi.org/10.1016/j.jmarsys.2008.11.018)
— `distance_to_front`

Haller G (2015). Lagrangian coherent structures. *Annual Review of Fluid
Mechanics* **47**, 137-162.
[doi:10.1146/annurev-fluid-010313-141322](https://doi.org/10.1146/annurev-fluid-010313-141322)
— `ftle`, `fsle`

d'Ovidio F, Fernández V, Hernández-García E, López C (2004). Mixing
structures in the Mediterranean Sea from finite-size Lyapunov exponents.
*Geophysical Research Letters* **31**(17).
[doi:10.1029/2004GL020328](https://doi.org/10.1029/2004GL020328) —
`fsle`

`distance_to_shore` measures against Natural Earth coastlines
(<https://www.naturalearthdata.com/>, public domain), via
`rnaturalearth`.

## See also

[`add_derivoce_covariates()`](https://camilleross.org/taupatch/reference/add_derivoce_covariates.md),
which runs the configured steps

## Examples

``` r
names(derivoce_covariates())
#>  [1] "horizontal_gradient" "vertical_gradient"   "temporal_gradient"  
#>  [4] "lag_covariate"       "integrate_covariate" "current_speed"      
#>  [7] "eke"                 "ftle"                "fsle"               
#> [10] "distance_to_front"   "distance_to_contour" "distance_to_isobath"
#> [13] "distance_to_shore"  
derivoce_covariates()$horizontal_gradient$units
#> [1] "source units per km"

# The column names a step will produce, before running it.
derivoce_covariates()$lag_covariate$outputs(list(vars = "CHL", n = 2))
#> [1] "CHL_lag2"
```
