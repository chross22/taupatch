# Map a function over a list, in parallel where that is possible

The one place in the package that spawns workers. Both callers — the
covariate jackknife and the multi-algorithm ensemble — are the same
shape: a few dozen independent model fits, each expensive enough that
the cost of handing it to another core disappears, and none of them
talking to each other.

## Usage

``` r
taupatch_lapply(x, fun, workers = 1L, seed = NULL)
```

## Arguments

- x:

  a list or vector to map over

- fun:

  the function to apply

- workers:

  how many workers; `1` runs sequentially

- seed:

  optional seed, so the mapping is reproducible

## Value

a list, as [`lapply()`](https://rdrr.io/r/base/lapply.html)

## Forks, not sockets

[`parallel::mclapply()`](https://rdrr.io/r/parallel/mclapply.html)
forks, so each worker starts with the fitted recipe, the folds and the
station table already in memory and copy-on-write keeps that free. A
PSOCK cluster would have to serialize all of it to every worker for
every task, which on a station table is most of the time the parallelism
was meant to save.

The cost is that forking does not exist on Windows, where this falls
back to running sequentially and says so rather than pretending. A
jackknife is still perfectly usable there — it is one model fit per
covariate per fold, which is minutes, not hours — it just does not get
faster with more cores.

## Reproducibility

Forked workers inherit the parent's RNG state, so without help every one
of them would draw the same random numbers — which for a random forest
means the members are correlated in a way nothing downstream can see.
`L'Ecuyer-CMRG` gives each worker an independent, reproducible
substream, and the previous RNG kind and seed are both restored on the
way out so a run's own seed still governs everything after this.
