# Plausible synthetic values for a named covariate

Values sit in each covariate's real range and units so mock output is
not misleading to look at. SST and CHL additionally carry the same
latitudinal and seasonal structure planted in the mock abundances,
giving the model real signal to recover; the rest are weakly structured
noise.

## Usage

``` r
mock_covariate_values(name, lat_effect, season_effect, n)
```

## Arguments

- name:

  covariate name from
  [`copernicus_covariates()`](https://camilleross.org/taupatch/reference/copernicus_covariates.md)

- lat_effect:

  scaled latitude, 0 at the south edge and 1 at the north

- season_effect:

  seasonal cycle term, ranging from -1 to 1

- n:

  number of grid points

## Value

numeric vector of length `n`
