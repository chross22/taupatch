# Resolve a threshold specification to an abundance value

The database zero-fills life stages a survey does not resolve rather
than NA-filling them (`original/create_database.R` lines 32-55 for
ECOMON), so a species with no coverage in the selected data yields a
column of zeros rather than NAs, which no NA filter would catch. That is
checked explicitly here.

## Usage

``` r
resolve_threshold(abundance, species)
```

## Arguments

- abundance:

  numeric vector of abundances

- species:

  the resolved species entry from
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

the abundance value separating patch from non-patch
