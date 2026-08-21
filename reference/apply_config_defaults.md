# Fill in config defaults

Defaults target ECOMON, which is what this model runs on essentially all
of the time, so a minimal config is a species name and a data path.

## Usage

``` r
apply_config_defaults(config)
```

## Arguments

- config:

  a parsed config list

## Value

`config` with missing optional fields populated
