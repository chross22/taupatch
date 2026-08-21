# One member's config

The run's config with the member's type set, and any per-type overrides
from `model.ensemble.settings` merged into the model block. The
uncertainty and jackknife blocks are left alone, so a member inherits
them exactly.

## Usage

``` r
member_config(config, type, settings)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- type:

  the member's model type

- settings:

  from
  [`ensemble_settings()`](https://camilleross.org/taupatch/reference/ensemble_settings.md)

## Value

a config list for that member
