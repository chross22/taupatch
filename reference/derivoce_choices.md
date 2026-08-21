# Derived covariates offerable for a given covariate selection

[`derivoce_covariates()`](https://camilleross.org/taupatch/reference/derivoce_covariates.md)
describes step *types*, which is what a config writes and not what a
person picks. A person picks a covariate: "the gradient of SST", not "a
horizontal_gradient step whose vars are SST". This turns a selection of
fetched covariates into the concrete derived covariates that can be
built from it, each already carrying the config step that produces it.

## Usage

``` r
derivoce_choices(
  selected,
  bathymetry = character(),
  fetchable = names(copernicus_covariates())
)
```

## Arguments

- selected:

  time-varying covariate names, as in `covariates.selected`

- bathymetry:

  static covariate names, as in `covariates.bathymetry`

- fetchable:

  covariates that could be added to the run if a derived one needs them;
  the whole Copernicus catalog by default

## Value

a list of candidates, each with `id` (the column it produces), `label`,
`group`, `expensive`, `step` (the `covariates.derivoce` entry), and
`requires` (covariates that must be fetched but are not yet selected)

## Details

This is the app's covariate picker, and it is a subset of what a config
can express. Where a step has a defensible default it is offered with
it: the Lyapunov exponents are offered backward, which finds the
attracting structures where water converges, since that is the question
a habitat model asks. Where there is no such default — a contour at
particular levels, a lag of some other number of steps, a forward
Lyapunov exponent — the step is left to the YAML, where the choice is
made explicitly rather than guessed at.

## See also

[`derivoce_steps_for()`](https://camilleross.org/taupatch/reference/derivoce_steps_for.md)
to turn chosen ids back into config steps

## Examples

``` r
choices <- derivoce_choices(c("SST", "BOTT", "CHL"))
vapply(choices, function(x) x$id, character(1))
#>  [1] "SST_grad"        "BOTT_grad"       "CHL_grad"        "SST_tgrad"      
#>  [5] "BOTT_tgrad"      "CHL_tgrad"       "SST_lag1"        "BOTT_lag1"      
#>  [9] "CHL_lag1"        "SST_lag12"       "BOTT_lag12"      "CHL_lag12"      
#> [13] "SST_int"         "BOTT_int"        "CHL_int"         "SST_front_dist" 
#> [17] "BOTT_front_dist" "CHL_front_dist"  "SST_BOTT_vgrad"  "speed"          
#> [21] "EKE"             "backward_ftle"   "backward_fsle"   "shore_dist"     
```
