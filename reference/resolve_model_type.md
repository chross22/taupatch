# Which model type a config asks for

`model.type` names it. A config written before there was a choice says
only `model.engine: ranger`, so an engine that identifies a type
unambiguously is accepted as one — those configs keep meaning what they
meant.

## Usage

``` r
resolve_model_type(config)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

the model type name
