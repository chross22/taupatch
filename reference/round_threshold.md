# Round a computed threshold to the nearest thousand

A percentile lands on whatever value the data happens to hold there -
9573.412 animals per square metre - and reporting a patch boundary to
three decimal places claims a precision the survey does not have. The
nearest thousand is a number that can be written in a paper.

## Usage

``` r
round_threshold(threshold)
```

## Arguments

- threshold:

  the computed abundance threshold

## Value

the threshold, rounded

## Details

Left alone below 1500, where rounding would move the boundary by more
than a third of its own value, and would take anything under 500 to zero
and make every station a patch.
