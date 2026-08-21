# Where zero falls on a novelty colour ramp

`scale_fill_gradientn()` places its colours at positions in `[0, 1]`
across the data range, so zero — the only value on a novelty surface
that means anything fixed — lands somewhere different on every map
unless it is put there deliberately. This returns positions that pin the
warm-to-cool break to the true zero, so red means extrapolated on every
month of a run rather than meaning "low for this month".

## Usage

``` r
novelty_scale_positions(novelty)
```

## Arguments

- novelty:

  the novelty values being plotted

## Value

a vector of six positions in `[0, 1]`, for the six ramp colours
