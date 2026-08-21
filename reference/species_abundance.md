# Extract a species' abundance from the raw database

Supports both forms the database offers: a precomputed total column, or
the per-stage columns that total was built from. The prefix form
generalizes what `original/create_database.R` hardcodes once per taxon.

## Usage

``` r
species_abundance(raw, species)
```

## Arguments

- raw:

  the raw database data frame

- species:

  the resolved species entry from
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

a numeric vector of abundances
