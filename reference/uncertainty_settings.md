# Projection uncertainty settings

A projected map is a surface of point estimates, and a point estimate on
its own invites more confidence than it has earned. Two different things
can be wrong with a cell, and they need separate answers because a cell
can be badly affected by one and untouched by the other:

## Usage

``` r
uncertainty_settings(config)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

`NULL` when off, otherwise a list with `method`, `replicates`, `level`,
and `novelty`

## Details

- **The fit could have been different.** Refit on slightly different
  data and the surface moves.
  [`ensemble_spread()`](https://camilleross.org/taupatch/reference/ensemble_spread.md)
  measures how much.

- **The cell may be somewhere the model has never seen.**
  [`novelty_surface()`](https://camilleross.org/taupatch/reference/novelty_surface.md)
  is the one that catches this, and the spread cannot: a narrow interval
  means the members agree, not that they are right. Where the covariates
  are off the end of the training data, members can agree perfectly and
  all be extrapolating.

The two do not track each other, and neither substitutes for the other.
They often move together — a resampled member's training range differs
from the full model's, so cells near the edge tend to be both novel and
unstable — but a confident prediction over a novel cell is exactly the
case a spread-only map reports as trustworthy. Read both.

Off by default. On a real grid over a decade the extra prediction passes
are a real multiplier, and most runs are iterations that only want the
mean surface.

    projection:
      uncertainty: true          # or the block below, for the non-defaults
      uncertainty:
        method: folds            # or: bootstrap
        replicates: 100          # bootstrap only
        level: 0.9               # interval width
        novelty: true

## See also

[`novelty_surface()`](https://camilleross.org/taupatch/reference/novelty_surface.md),
[`ensemble_spread()`](https://camilleross.org/taupatch/reference/ensemble_spread.md)

## Examples

``` r
config <- load_config(
  system.file("configs/mock_test.yaml", package = "taupatch")
)
uncertainty_settings(config)                      # NULL: off by default
#> NULL

config$projection$uncertainty <- TRUE
uncertainty_settings(config)
#> $method
#> [1] "folds"
#> 
#> $replicates
#> [1] 100
#> 
#> $level
#> [1] 0.9
#> 
#> $novelty
#> [1] TRUE
#> 

config$projection$uncertainty <- list(method = "bootstrap", level = 0.95)
uncertainty_settings(config)
#> $method
#> [1] "bootstrap"
#> 
#> $replicates
#> [1] 100
#> 
#> $level
#> [1] 0.95
#> 
#> $novelty
#> [1] TRUE
#> 
```
