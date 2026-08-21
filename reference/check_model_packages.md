# Check that the packages a model type needs are installed

Checked before fitting rather than at load, since a run needs only the
one type it asks for and nothing here is a hard dependency.

## Usage

``` r
check_model_packages(type)
```

## Arguments

- type:

  a model type name

## Value

`TRUE` invisibly; errors otherwise
