# Locate the Copernicus Marine client

[`Sys.which()`](https://rdrr.io/r/base/Sys.which.html) is enough from a
terminal and often not enough anywhere else. An app launched from
RStudio or any GUI inherits a minimal environment rather than the
shell's, so a client installed under conda is on the user's PATH and not
on R's. The usual install locations are checked as well, and the answer
is an absolute path so that nothing downstream has to search again —
including the parallel workers, which start with no PATH additions at
all.

## Usage

``` r
copernicus_client()
```

## Value

the path to the client, or `""` when it cannot be found

## Examples

``` r
copernicus_client()
#> [1] ""
```
