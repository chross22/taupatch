# Per-covariate steps applied before products are joined

Copernicus products arrive on different grids, and
[`fetch_covariates()`](https://camilleross.org/taupatch/reference/fetch_covariates.md)
reconciles them by joining everything onto one. That join is
all-or-nothing: every covariate is either upsampled or left alone
according to a single `covariates.grid` choice, with no say in how.

## Usage

``` r
prejoin_steps()
```

## Value

a named list, one entry per step type, each with `label`, `description`,
`targets` (the step fields naming covariates), and `fun`

## Details

A `covariates.prejoin` block is that say. Each step names a covariate
and resamples it, or fills its gaps, *before* the join happens — so the
join then sees grids that already agree, and does nothing to them.

The reason to want this is that the right treatment differs per
covariate. Ocean-colour chlorophyll is a 4 km optical retrieval full of
cloud gaps; physics is a 0.083 degree model with no gaps at all.
Bringing chlorophyll up to the physics grid by averaging is a defensible
summary of values that were really measured. Interpolating physics down
to 4 km invents structure. One global setting cannot express that, and
the `upsampled` warning exists precisely because the current join cannot
either.

The computation is
[`datamatch::upscale_grid()`](https://camilleross.org/datamatch/reference/upscale_grid.html),
[`datamatch::downscale_grid()`](https://camilleross.org/datamatch/reference/downscale_grid.html),
and
[`datamatch::fill_satellite_gaps()`](https://camilleross.org/datamatch/reference/fill_satellite_gaps.html)
throughout, which own it.

## See also

[`apply_prejoin_steps()`](https://camilleross.org/taupatch/reference/apply_prejoin_steps.md),
which runs the configured steps

## Examples

``` r
names(prejoin_steps())
#> [1] "upscale"   "downscale" "fill_gaps"
prejoin_steps()$upscale$description
#> [1] "Combines the source cells inside each target cell into one value. This is the direction that discards detail, which is the safe direction: every value in the result summarises values that were really measured. `method` chooses the summary - median resists the retrieval artefacts at cloud edges that make satellite chlorophyll's outliers one-sided."
```
