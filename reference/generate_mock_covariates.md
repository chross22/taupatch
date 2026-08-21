# Generate synthetic environmental covariates

Produces the same shape
[`datamatch::accessEnvDat()`](https://camilleross.org/datamatch/reference/accessEnvDat.html)
returns, so the pipeline runs identically against mock and Copernicus
data. Covariates carry the same latitudinal and seasonal structure
planted in the mock abundances, so the model has something real to
learn.

## Usage

``` r
generate_mock_covariates(
  config,
  years = NULL,
  months = NULL,
  resolution = 0.25,
  seed = 42
)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- years:

  years to generate

- months:

  months to generate

- resolution:

  grid spacing in degrees

- seed:

  random seed

## Value

an `sf` POINT object matching
[`fetch_covariates()`](https://camilleross.org/taupatch/reference/fetch_covariates.md)'s
contract
