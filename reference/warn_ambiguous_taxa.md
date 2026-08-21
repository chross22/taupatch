# Warn about taxon names this cannot read confidently

Every rule for reading a taxon out of a column name is a guess about how
the export was written, and the guesses fail quietly: a column read as a
total when it is really a stage still produces a plausible number. These
are the three ways it goes wrong that can be spotted from the names
alone.

## Usage

``` r
warn_ambiguous_taxa(taxa, stage_pattern)
```

## Arguments

- taxa:

  a
  [`zoop_taxa()`](https://camilleross.org/taupatch/reference/zoop_taxa.md)
  table

- stage_pattern:

  the pattern used to find stages

## Value

`taxa`, invisibly; warns or errors as appropriate
