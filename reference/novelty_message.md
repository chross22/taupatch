# Summarise a novelty surface for the run log

A map is easy not to look at. This is the one line that says whether it
needed looking at.

## Usage

``` r
novelty_message(novelty, novel_variable)
```

## Arguments

- novelty:

  the `novelty` column from
  [`novelty_surface()`](https://camilleross.org/taupatch/reference/novelty_surface.md)

- novel_variable:

  the matching `novel_variable` column

## Value

a single string, or `NULL` when nothing is extrapolated
