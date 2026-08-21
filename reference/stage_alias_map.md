# Stage columns that are aliased to a single-stage name

Some species report a stage under a column name that does not look like
a single stage. `cfin_CV_VI` is the adult/late-stage count — it is how
ECOMON reports *C. finmarchicus*, which does not resolve CV from CVI —
so it is offered as `adult`, matching how `ctyp` and `pseudo` name
theirs.

## Usage

``` r
stage_alias_map(column_prefix)
```

## Arguments

- column_prefix:

  the species' column prefix in the database

## Value

named list of `list(column=, spans=)`, keyed by the stage name to
present, or `NULL` when the species needs no aliases

## Details

`spans` records which single stages the column covers, so a selection
mixing an alias with a stage it already contains can be rejected instead
of double-counting.
