# Species a formatted database could model

The config's species catalog names the taxa a run was set up for. A
formatted export carries every taxon the survey counted, which is most
of a hundred, and any of them can be modelled. This reads the candidates
off the file.

## Usage

``` r
available_species(
  zoop_file,
  stage_pattern = stage_suffix_pattern(),
  exclude = measurement_columns()
)
```

## Arguments

- zoop_file:

  path to a formatted database, or its column names

- stage_pattern:

  regular expression matching a life stage

- exclude:

  columns to leave out. The default drops the in-situ measurements the
  ECOMON export carries, which are numeric columns that are not taxa;
  pass [`character()`](https://rdrr.io/r/base/character.html) to see
  them.

## Value

a data frame of `species` (the column header name), `shorthand`, `form`
(`"total"` or `"stages"`), and `stages`, one row per candidate

## Details

A taxon with stage columns is reported once, as a prefix, since that is
how a config selects it and how its stages are summed. Everything else
is reported as a total.

## What it cannot tell you

A formatted database has had the units cut off its taxon columns, so
nothing in the name distinguishes a taxon from the in-situ measurements
the export also carries. `STATION_DEPTH` and `BTM_TEMP` are candidates
here in exactly the way `CALANUS_FINMARCHICUS` is. The list is what
could be an abundance column, not what is one. Run
[`zoop_taxa()`](https://camilleross.org/taupatch/reference/zoop_taxa.md)
against the raw export for the answer the raw column names still hold.

## See also

[`zoop_taxa()`](https://camilleross.org/taupatch/reference/zoop_taxa.md),
[`species_catalog_from()`](https://camilleross.org/taupatch/reference/species_catalog_from.md)

## Examples

``` r
available_species(c("station", "year", "month", "day", "lon", "lat",
                    "CALANUS_FINMARCHICUS", "PSEUDOCALANUS_SPP_CIV",
                    "PSEUDOCALANUS_SPP_CV"))
#>                species shorthand   form  stages
#> 1 CALANUS_FINMARCHICUS      cfin  total        
#> 2    PSEUDOCALANUS_SPP      pcal stages CIV, CV
```
