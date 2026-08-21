# Covariates a set of derived choices needs fetching

A derived covariate is computed from others, and those have to be
downloaded whether or not anyone wants to model them. Asking for the
FSLE means fetching the two velocity components; it does not mean
wanting them as predictors.

## Usage

``` r
derivoce_required_inputs(ids, selected, bathymetry = character())
```

## Arguments

- ids:

  column names chosen from
  [`derivoce_choices()`](https://camilleross.org/taupatch/reference/derivoce_choices.md)

- selected:

  covariates already selected

- bathymetry:

  static covariate names

## Value

character vector of covariates to fetch that are not already selected

## See also

[`derivoce_steps_for()`](https://camilleross.org/taupatch/reference/derivoce_steps_for.md)

## Examples

``` r
# The FSLE needs the velocity components, which nobody asked to model.
derivoce_required_inputs("backward_fsle", selected = "SST")
#> [1] "UO" "VO"
```
