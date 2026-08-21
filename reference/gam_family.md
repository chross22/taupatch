# The family a GAM is fitted with

The response is a two-level factor, so the family is binomial and that
is not a choice. What the config picks is the link. `logit` is the
default and reads as log-odds; `cloglog` is asymmetric and is the one to
consider when patches are rare, which they are here by construction.

## Usage

``` r
gam_family(link = NULL)
```

## Arguments

- link:

  a link name, or `NULL` for the default

## Value

a `family` object
