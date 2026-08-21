# Load and validate a taupatch run config

Reads a run config YAML (see `inst/configs/`), resolves paths relative
to `paths.project_dir`, and validates the parts that are cheap to check
before a run rather than midway through one: the active species exists
in the catalog, each species resolves to an abundance column, thresholds
are well-formed, and the declared columns actually exist in the
zooplankton CSV.

## Usage

``` r
load_config(path)
```

## Arguments

- path:

  path to a config YAML file

## Value

the parsed config list with `paths` resolved to absolute paths and a
derived `species$resolved` entry describing the active species
