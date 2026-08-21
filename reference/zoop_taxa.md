# Taxon columns in a raw zooplankton export

The export names every taxon column for the taxon and the units it is
reported in: `CALANUS_FINMARCHICUS_10M2` is abundance per 10 m². Some
datasets also resolve life stages, marked by a `C` and a Roman numeral —
`CALANUS_FINMARCHICUS_CV_10M2` is the fifth copepodite stage. A column
without one is the total for that taxon.

## Usage

``` r
zoop_taxa(header, suffix = "_10M2", stage_pattern = stage_suffix_pattern())
```

## Arguments

- header:

  column names, or a path to a CSV to read them from

- suffix:

  the units suffix marking an abundance column

- stage_pattern:

  regular expression matching a stage on the end of a taxon name. The
  default is a `C` followed by a Roman numeral one to six.

## Value

a data frame with one row per taxon column: `column` as found, `taxon`,
`shorthand`, `stage` (`NA` when the column is a total), `name` (the
column the formatted database will carry), and the `per`/`unit` the
counts are reported in

## Details

Read off the header rather than kept as a list here. The export carries
the better part of a hundred taxa, gains and loses them between
versions, and resolves stages for some datasets and not others. A fixed
list would be wrong shortly after it was written.

## Examples

``` r
zoop_taxa(c("CALANUS_FINMARCHICUS_10M2", "CALANUS_FINMARCHICUS_CV_10M2"))
#>                         column                taxon shorthand stage
#> 1    CALANUS_FINMARCHICUS_10M2 CALANUS_FINMARCHICUS      cfin  <NA>
#> 2 CALANUS_FINMARCHICUS_CV_10M2 CALANUS_FINMARCHICUS      cfin    CV
#>                      name per unit
#> 1    CALANUS_FINMARCHICUS  10   M2
#> 2 CALANUS_FINMARCHICUS_CV  10   M2
```
