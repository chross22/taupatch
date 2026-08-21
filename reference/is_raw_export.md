# Whether a header is a raw export rather than a station database

A raw export names its coordinates `LATITUDE`/`LONGITUDE` and carries
one `DATE`; a station database uses `lat`/`lon` and separate year, month
and day. The two are told apart by that alone, which is enough to know
whether a file needs
[`format_zoop_data()`](https://camilleross.org/taupatch/reference/format_zoop_data.md)
run over it first.

## Usage

``` r
is_raw_export(header)
```

## Arguments

- header:

  column names, or a path to a CSV to read them from

## Value

`TRUE` when the file looks like a raw export

## Examples

``` r
is_raw_export(c("STATION", "LATITUDE", "LONGITUDE", "DATE"))
#> [1] TRUE
is_raw_export(c("station", "lat", "lon", "year", "month", "day"))
#> [1] FALSE
```
