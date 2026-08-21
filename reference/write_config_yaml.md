# Serialize a config to YAML

[`yaml::as.yaml()`](https://yaml.r-lib.org/reference/as.yaml.html)
writes logicals as `yes`/`no`. That is valid YAML 1.1 and round-trips
correctly, but every config in this package is written `true` / `false`,
and a generated file that does not look like the hand-written ones is
half the reason the generator was worth avoiding.

## Usage

``` r
write_config_yaml(config)
```

## Arguments

- config:

  a config list

## Value

a YAML string
