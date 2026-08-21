# How many workers to run with

`NULL` or `true` means "as many as this machine can spare", which is one
fewer than its physical cores — leaving one is what keeps the session it
was launched from responsive. `false` or `1` is sequential.
`options(mc.cores=)` overrides the default, since that is the option R
users already reach for.

## Usage

``` r
resolve_workers(workers = NULL, n = 1L, quiet = FALSE)
```

## Arguments

- workers:

  the configured value: `NULL`, a logical, or a count

- n:

  how many tasks there are to spread

- quiet:

  whether to suppress the Windows fallback message

## Value

an integer worker count, at least 1

## Details

Capped at `n`, since a task list of six cannot use twelve workers;
forced to 1 on Windows, where
[`taupatch_lapply()`](https://camilleross.org/taupatch/reference/taupatch_lapply.md)
cannot fork; and capped again at whatever
[`core_ceiling()`](https://camilleross.org/taupatch/reference/core_ceiling.md)
allows.
