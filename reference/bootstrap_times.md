# How many bootstrap resamples a run should draw

`model.bootstrap` sets it. Zero or `false` turns the intervals off,
which is the escape hatch for a run where even a few seconds of
resampling is not wanted.

## Usage

``` r
bootstrap_times(config)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

an integer count, or `0L` when off
