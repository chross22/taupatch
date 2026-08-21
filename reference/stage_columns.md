# Resolve requested life stages to database columns

With no stages requested, every stage column is summed — including the
combination columns — which reproduces the database's `<prefix>_total`.
This matters for ECOMON, where `cfin`'s counts live in the combination
column `cfin_CV_VI` and the single stages are zero-filled.

## Usage

``` r
stage_columns(header, column_prefix, stages = NULL)
```

## Arguments

- header:

  column names of the database

- column_prefix:

  the species' column prefix in the database

- stages:

  stage codes to select; `NULL` sums every stage

## Value

character vector of column names to sum

## Details

An explicit selection, by contrast, is restricted to individually
resolved stages, since combination columns overlap them and summing a
mix would double-count.
