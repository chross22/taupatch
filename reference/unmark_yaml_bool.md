# Strip the boolean marker, leaving what the file wrote

Anchored at the start rather than replaced wherever it appears, so a
quoted value that happens to contain the marker's text further along is
left alone.

## Usage

``` r
unmark_yaml_bool(x)
```

## Arguments

- x:

  a character vector, or `NULL` for an unnamed list

## Value

`x` with any marker prefix removed
