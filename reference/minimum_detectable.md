# The smallest difference a design could have detected

Reported instead of "observed power", which is the statistic this is
usually confused with and which carries no information a p-value does
not — it is a deterministic function of it (Hoenig and Heisey 2001). The
minimum detectable difference is about the *design* rather than about
the result, which is what makes it worth reading beside a null finding.

## Usage

``` r
minimum_detectable(std_err, df, level = 0.95, power = 0.8)
```

## Arguments

- std_err:

  the corrected standard error of the difference

- df:

  degrees of freedom

- level:

  confidence level

- power:

  the power to solve at

## Value

the smallest detectable difference, or `NA_real_`

## References

Hoenig JM, Heisey DM (2001). The abuse of power: the pervasive fallacy
of power calculations for data analysis. *The American Statistician*
**55**(1), 19-24.
[doi:10.1198/000313001300339897](https://doi.org/10.1198/000313001300339897)
