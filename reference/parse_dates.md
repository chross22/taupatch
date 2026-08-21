# Parse dates against candidate formats

Picks the first format that accounts for every non-missing value, rather
than the first that parses any. A format that parses most of a column
and `NA`s the rest is the failure mode worth catching: those rows go
missing later, far from the cause.

## Usage

``` r
parse_dates(values, formats)
```

## Arguments

- values:

  character dates

- formats:

  candidate `strptime` formats, in order

## Value

a `Date` vector
