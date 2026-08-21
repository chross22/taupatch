# Config steps for a set of chosen derived covariates

Ordered as
[`derivoce_choices()`](https://camilleross.org/taupatch/reference/derivoce_choices.md)
lists them rather than as they were picked, so a run does not depend on
the order someone happened to click in.

## Usage

``` r
derivoce_steps_for(ids, selected, bathymetry = character())
```

## Arguments

- ids:

  column names chosen from
  [`derivoce_choices()`](https://camilleross.org/taupatch/reference/derivoce_choices.md)

- selected:

  time-varying covariate names

- bathymetry:

  static covariate names

## Value

a list suitable for `covariates.derivoce`

## Examples

``` r
derivoce_steps_for("SST_grad", selected = c("SST", "CHL"))
#> [[1]]
#> [[1]]$type
#> [1] "horizontal_gradient"
#> 
#> [[1]]$vars
#> [1] "SST"
#> 
#> 
```
