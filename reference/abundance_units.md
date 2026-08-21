# The count and the unit a suffix encodes

`_10M2` is not a unit, it is a count and a unit: animals per ten square
metres. Splitting them is what lets abundance be reported per one of
something, which is the form anyone comparing two surveys needs.

## Usage

``` r
abundance_units(suffix)
```

## Arguments

- suffix:

  a units suffix, with or without its leading underscore

## Value

`list(per=, unit=)`, the number the values are counted over and the unit
that remains. `per` is 1 when the suffix carries no number.

## Examples

``` r
abundance_units("_10M2")
#> $per
#> [1] 10
#> 
#> $unit
#> [1] "M2"
#> 
abundance_units("_100M3")
#> $per
#> [1] 100
#> 
#> $unit
#> [1] "M3"
#> 
```
