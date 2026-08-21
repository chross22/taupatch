# The abundance suffix a raw export uses

Read off the header rather than assumed, so a file counting per 100
cubic metres is handled without being told. The most common suffix wins
when a file carries more than one, which
[`warn_mixed_units()`](https://camilleross.org/taupatch/reference/warn_mixed_units.md)
reports separately.

## Usage

``` r
raw_abundance_suffix(header)
```

## Arguments

- header:

  the file's column names

## Value

the suffix, including its leading underscore; `"_10M2"` when the header
has none, since that is what the ECOMON export uses

## Examples

``` r
raw_abundance_suffix(c("STATION", "CALANUS_FINMARCHICUS_100M3"))
#> [1] "_100M3"
```
