# Default species catalog

The three taxa the original zooplankton database resolves, each
thresholded at the 90th percentile as in Ross et al. (2023).

## Usage

``` r
default_species_catalog()
```

## Value

a named list suitable for `species.catalog`

## Details

Each entry uses `column_prefix` with no `stages`, meaning "sum every
life stage" — equivalent to the `<species>_total` column, but letting a
run narrow to particular stages without changing the catalog. `pcal` is
the one species whose preferred name differs from its database prefix
(`pseudo_*`), so it declares the alias explicitly.
