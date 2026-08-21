# Conventional shorthand for a taxon name

The genus initial and the first three letters of the species epithet,
lower case. `CALANUS_FINMARCHICUS` gives `cfin` and
`CENTROPAGES_TYPICUS` gives `ctyp`. A name with no epithet uses its
first four letters.

## Usage

``` r
taxon_shorthand(taxon)
```

## Arguments

- taxon:

  taxon names, as they appear in the column header

## Value

character vector of shorthands, one per input

## Details

`Pseudocalanus` is the one exception, and is listed rather than derived:
its conventional shorthand is `pcal`, from the `calanus` inside the
genus name, which the rule above cannot produce.

The column header remains the identity - it is what the data carries,
and it is matched without regard to case. This is only what a config
says out loud as `active:` and what the app shows in its picker.

Two taxa can collide: `CALANUS_FINMARCHICUS` and a hypothetical
`CALANUS_FINLANDICUS` both give `cfin`. That is reported rather than
resolved, since a name invented to break the tie would be a name nobody
uses.

## Examples

``` r
taxon_shorthand(c("CALANUS_FINMARCHICUS", "CENTROPAGES_TYPICUS",
                  "PSEUDOCALANUS_SPP", "METRIDIA_LUCENS"))
#> [1] "cfin" "ctyp" "pcal" "mluc"
```
