# Attach covariates to zooplankton stations

Matches each station to the nearest covariate grid point within the
station's own time period, via
[`datamatch::matchData()`](https://camilleross.org/datamatch/reference/matchData.html).
This replaces `original/format_model_data.R`, which rounded both sets of
coordinates to one decimal place and then joined on exact equality —
silently dropping any station whose rounded position had no covariate
match.

## Usage

``` r
attach_covariates(dat, env_dat, config)
```

## Arguments

- dat:

  station data from
  [`load_zoop_data()`](https://camilleross.org/taupatch/reference/load_zoop_data.md)

- env_dat:

  covariate data from
  [`fetch_covariates()`](https://camilleross.org/taupatch/reference/fetch_covariates.md)

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

`dat` with one column per covariate variable, with unmatched rows
dropped

## Details

`matchData()` matches at the covariate data's own temporal resolution,
which for this pipeline is monthly: the original used monthly covariate
composites, and the Copernicus products configured here are monthly
means (`...P1M-m`) carrying one time step per month, while stations fall
on arbitrary days.
