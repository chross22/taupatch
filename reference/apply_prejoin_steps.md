# Apply the configured pre-join steps to the fetched products

Steps run in order, each against the product object holding the
covariate it names, so a later step sees what an earlier one produced.

## Usage

``` r
apply_prejoin_steps(per_dataset, config)
```

## Arguments

- per_dataset:

  a list of `sf` POINT objects, one per fetched product

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

a list of `sf` POINT objects, ready to join

## Details

A step naming one covariate of a product that carries several splits it
out first.
[`datamatch::upscale_grid()`](https://camilleross.org/datamatch/reference/upscale_grid.html)
returns only the columns it was asked to resample, so regridding
chlorophyll in place would silently drop the other plankton variables
sharing its dataset. Splitting means the rest stay on their own grid and
reach the join intact.

## See also

[`prejoin_steps()`](https://camilleross.org/taupatch/reference/prejoin_steps.md)
for the step types
