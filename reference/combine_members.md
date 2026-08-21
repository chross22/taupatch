# Apply every combination rule to a matrix of member predictions

All four rules at once, because they cost nothing next to the
predictions they are computed from and a projection writes all of them.
The spread columns come out of the same matrix.

## Usage

``` r
combine_members(probabilities, weights, cutoffs)
```

## Arguments

- probabilities:

  rows by members

- weights:

  one per member, in the same column order

- cutoffs:

  each member's own TSS-optimal cutoff, for `committee`

## Value

a named list: one entry per rule, plus `algorithm_sd` and
`algorithm_range`
