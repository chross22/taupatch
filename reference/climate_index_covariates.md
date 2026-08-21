# Climate indices selectable as covariates

Basin-scale modes of variability — the NAO, the AMO and the rest — from
[`datamatch::climate_indices()`](https://camilleross.org/datamatch/reference/climate_indices.html),
which owns them.

## Usage

``` r
climate_index_covariates()
```

## Value

a named list, one entry per index, each with `label`, `source`, and
`description`

## Details

Unlike everything else in the covariate catalog these have no spatial
structure. One value per month applies to the whole study area, so an
index cannot say where a patch is, only which years and seasons were
unusual. That makes them useful for the interannual part of the signal
and useless for the map: a projection differs between two months partly
because the index differs, but the index shifts every cell by the same
amount.

## References

Each index is somebody's published product, and the `source` field names
whose.
[`datamatch::index_dictionary()`](https://camilleross.org/datamatch/reference/index_dictionary.html)
carries the citation for each one at runtime; two of them (`LCR`,
`AMOC`) are the output of specific papers and should be cited when used.
See datamatch's README for the list.

## Examples

``` r
names(climate_index_covariates())
#> [1] "NAO"  "AO"   "AMO"  "PDO"  "LCR"  "AMOC"
```
