# Individually resolved life stages

The copepodite stages plus the adult stage. Selecting these is
unambiguous: they never overlap, so summing any subset counts each
animal once.

## Usage

``` r
single_stages()
```

## Value

character vector of single-stage codes

## Details

The database also holds combination columns spanning several stages
(`cfin_CV_VI`, `pseudo_CI_IV`, `ctyp_IV_VI`, and the unstaged `ctyp_C`).
Those are deliberately not offered for selection, because they overlap
the single stages — summing `CV` together with `CV_VI` would count the
same animals twice.
