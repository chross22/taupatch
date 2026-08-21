# Add one transformation step to a recipe

A function rather than inline code because `recipes` captures its
selection as an unevaluated quosure. Adding the steps directly inside a
loop leaves every one of them pointing at the same `vars` binding, which
by the time `prep()` runs holds the last iteration's value — so a config
asking for `log10` on chlorophyll and `sqrt` on temperature silently
applies both to temperature and neither to chlorophyll. Each call here
gets its own frame, so each step's quosure resolves to the variables it
was built for.

## Usage

``` r
add_transform_step(rec, vars, entry)
```

## Arguments

- rec:

  a
  [`recipes::recipe`](https://recipes.tidymodels.org/reference/recipe.html)

- vars:

  covariate names the transform applies to

- entry:

  the matching
  [`covariate_transforms()`](https://camilleross.org/taupatch/reference/covariate_transforms.md)
  entry

## Value

`rec` with the step appended

## Details

The [`force()`](https://rdrr.io/r/base/force.html) is the load-bearing
half. Without it `vars` is still an unforced promise pointing back at
the caller's loop variable, so moving the call into a function changes
nothing: the quosure captures this frame, the promise is evaluated at
`prep()` time, and it reads the loop variable's final value.
