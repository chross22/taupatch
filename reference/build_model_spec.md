# Build the model specification

Random forest by default, matching the original. Which model is fitted
is a config field rather than baked into the code, so comparing a forest
against a GAM is a one-word edit — which is what the app's model picker
exposes.

## Usage

``` r
build_model_spec(config)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

## Value

a `parsnip` model specification
