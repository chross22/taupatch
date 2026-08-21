# The suffix marking a life stage on a taxon column

A `C` and a Roman numeral is the core of it, but the databases in use
carry several more forms: a bare `C` for unstaged copepodites, `adult`,
`total`, a combination spanning two stages (`CV_VI`, `CI_IV`), and
combinations written without the `C` at all (`ctyp_IV_VI`). All are
suffixes on a taxon name, and a rule recognising only the first splits
one taxon into several species - `cfin_CV_VI` read as an animal called
"cfin_CV_VI" rather than as some of cfin.

## Usage

``` r
stage_suffix_pattern()
```

## Value

a regular expression with one capture group, the suffix

## Details

Matched without regard to case, because the databases disagree: the raw
export is upper case throughout, while `original/create_database.R`
writes a lower case taxon with an upper case stage.

## Examples

``` r
grepl(stage_suffix_pattern(), "cfin_CV", ignore.case = TRUE)
#> [1] TRUE
```
