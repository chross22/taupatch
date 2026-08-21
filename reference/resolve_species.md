# Describe the active species

Resolves the active species to the concrete abundance definition the
rest of the pipeline uses, so no downstream code re-reads the catalog.

## Usage

``` r
resolve_species(config)
```

## Arguments

- config:

  a parsed config list

## Value

`list(name=, abundance_column=, column_prefix=, stages=, threshold=)`,
where exactly one of `abundance_column`/`column_prefix` is non-`NULL`

## Details

`column_prefix` defaults to the catalog key, so a species whose database
columns are named after it needs no prefix at all. Setting it explicitly
aliases a preferred name onto different column names — `pcal` is the one
case in this database, where the columns are `pseudo_*`.
