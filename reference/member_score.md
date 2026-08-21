# One member's score, on the metric the weights use

Read out of the member's own evaluation table rather than recomputed, so
the number that decides a member's weight is the number reported for it.
The threshold-dependent metrics are taken at the member's own
TSS-optimal cutoff, which is the only fair comparison — reading TSS at
0.5 would score every member on a cutoff that suits none of them.

## Usage

``` r
member_score(member, metric = "tss")
```

## Arguments

- member:

  a
  [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)
  result

- metric:

  `"tss"`, `"roc_auc"`, `"pr_auc"`, or `"equal"`

## Value

the score, or `NA_real_`
