# A species catalog for the taxa in a raw export

Writes the `species.catalog` block a config needs, one entry per taxon.
Suitable for passing to
[`generate_config()`](https://camilleross.org/taupatch/reference/generate_config.md)
as `species`.

## Usage

``` r
species_catalog_from(
  header,
  suffix = "_10M2",
  stage_pattern = stage_suffix_pattern(),
  threshold = list(type = "percentile", value = 0.9),
  aliases = NULL
)
```

## Arguments

- header:

  column names, a raw export, or a path to one

- suffix:

  the units suffix marking taxon columns

- stage_pattern:

  regular expression matching a life stage

- threshold:

  the threshold every entry gets

- aliases:

  optional named character vector giving short config keys to taxa, e.g.
  `c(cfin = "CALANUS_FINMARCHICUS")`

## Value

a named list suitable for `species.catalog`

## Details

Which form an entry takes depends on the file. A taxon whose stages the
dataset resolves gets `column_prefix`, so a run can select stages or
leave them out to sum every one. A taxon reported only as a total gets
`abundance_column`, because there is no prefix for anything to match.

A taxon carrying both a total and some stages gets the prefix form, and
the bare total column is then not read: `column_prefix` matches only
`<taxon>_<something>`, which is what keeps the total from being summed
alongside the stages that compose it. Worth knowing that summing the
resolved stages need not reproduce the reported total, since a dataset
may resolve only some of them. Use `abundance_column` explicitly if the
total is what you want.

## See also

[`format_zoop_data()`](https://camilleross.org/taupatch/reference/format_zoop_data.md),
[`generate_config()`](https://camilleross.org/taupatch/reference/generate_config.md)

## Examples

``` r
header <- c("CALANUS_FINMARCHICUS_CV_10M2", "CALANUS_FINMARCHICUS_CVI_10M2",
            "CENTROPAGES_TYPICUS_10M2")

# cfin resolves stages here, so it gets a prefix; ctyp is a total.
species_catalog_from(header, aliases = c(cfin = "CALANUS_FINMARCHICUS"))
#> $cfin
#> $cfin$column_prefix
#> [1] "CALANUS_FINMARCHICUS"
#> 
#> $cfin$threshold
#> $cfin$threshold$type
#> [1] "percentile"
#> 
#> $cfin$threshold$value
#> [1] 0.9
#> 
#> 
#> 
#> $ctyp
#> $ctyp$abundance_column
#> [1] "CENTROPAGES_TYPICUS"
#> 
#> $ctyp$threshold
#> $ctyp$threshold$type
#> [1] "percentile"
#> 
#> $ctyp$threshold$value
#> [1] 0.9
#> 
#> 
#> 
```
