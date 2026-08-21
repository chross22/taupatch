# Normalize one derivoce step specification

A step is a mapping of `type` plus the arguments for that type. A bare
string is accepted as shorthand for a step with no arguments, so
`- distance_to_shore` reads as it should.

## Usage

``` r
normalize_derivoce_spec(spec)
```

## Arguments

- spec:

  one entry of `covariates.derivoce`

## Value

the spec as a list with a validated `type` and vector-valued fields
