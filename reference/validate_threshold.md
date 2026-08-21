# Validate one species' threshold specification

The original pipeline inferred percentile-vs-absolute from whether the
value was below 1, which silently misreads any real abundance threshold
under 1. The type is explicit here instead.

## Usage

``` r
validate_threshold(threshold, species_name)
```

## Arguments

- threshold:

  a `list(type=, value=)`

- species_name:

  species name, for error messages

## Value

`TRUE` invisibly; errors otherwise
