# In-situ measurement columns the raw export carries

A formatted database has had the units cut off its taxon columns, so
nothing in a name distinguishes `CALANUS_FINMARCHICUS` from `BTM_TEMP`.
These are the measurement columns the ECOMON export is known to carry,
so that a list of modellable species is not padded with water
temperature.

## Usage

``` r
measurement_columns()
```

## Value

character vector of column names

## Details

A list rather than a rule, because there is no rule: the export names
its measurements no differently from its animals. Anything not here and
not structural is taken to be a taxon.

`SFC_TMEP` is in the list twice over, spelled as the export spells it
and as it would be spelled correctly, so a file that has since been
fixed is still handled.

## Examples

``` r
measurement_columns()
#>  [1] "CRUISE_NAME"    "EVENT_PK_SEQ"   "NET_PK_SEQ"     "ZOO_GEAR"      
#>  [5] "TOW_PROTOCOL"   "TOW_PROFILE"    "SORT_TYPE"      "STATION_DEPTH" 
#>  [9] "SFC_TMEP"       "SFC_TEMP"       "SFC_SALT"       "BTM_TEMP"      
#> [13] "BTM_SALT"       "BIO_VOLUME_1M2"
```
