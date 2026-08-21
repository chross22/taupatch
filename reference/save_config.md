# Write a config list to a YAML file

The counterpart to
[`load_config()`](https://camilleross.org/taupatch/reference/load_config.md),
and what both
[`generate_config()`](https://camilleross.org/taupatch/reference/generate_config.md)
and the app's download button use, so a config saved from a session and
one written programmatically are the same file.

## Usage

``` r
save_config(config, path, header = TRUE)
```

## Arguments

- config:

  a config list

- path:

  where to write it

- header:

  whether to lead the file with orientation comments

## Value

`path`, invisibly

## Details

`species$resolved` is dropped.
[`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)
derives it on the way in, and writing it back would put a computed field
in a file meant to be edited by hand — and one that silently overrides
the catalog it was derived from.

## Examples

``` r
if (FALSE) { # \dontrun{
config <- load_config("my_run.yaml")
config$model$trees <- 1000
save_config(config, "my_run_1000.yaml")
} # }
```
