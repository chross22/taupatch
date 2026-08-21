# Pool the members' resample intervals

Each member carries its own resample ensemble when
`projection.uncertainty` is on. Rather than reporting one member's
interval, or four of them, this pools every member's every replicate
into one set and takes the interval from that — so the reported interval
covers refit variability *and* algorithm choice at once, which is what a
reader of a single interval column assumes it does.

## Usage

``` r
ensemble_member_spread(members, weights, newdata, level = 0.9)
```

## Arguments

- members:

  the qualifying members that predicted successfully

- weights:

  their weights

- newdata:

  the cells to predict

- level:

  interval width

## Value

a data frame of `suitability_sd`, `suitability_lower`,
`suitability_upper` and `n_members`; `NULL` when no member has an
ensemble

## Details

Members are represented in proportion to their weight by drawing that
share of the pooled columns, so a member with a tenth of the weight does
not contribute a quarter of the interval just for having been fitted.
