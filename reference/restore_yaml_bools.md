# Turn marked scalars back into keys and logicals

Names get the source text they were written with; values get the logical
that text meant. A sequence that mixes a marked scalar with an unmarked
one cannot be a logical vector, so it keeps the text — `[true, maybe]`
is a list of two strings, which is the only reading available.

## Usage

``` r
restore_yaml_bools(x)
```

## Arguments

- x:

  a parsed YAML value

## Value

`x` with markers resolved
