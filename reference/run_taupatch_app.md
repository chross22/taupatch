# Launch the taupatch Shiny app

Opens a GUI for selecting a species, threshold, extent, and model
settings, running the pipeline, and browsing the resulting monthly
suitability maps.

## Usage

``` r
run_taupatch_app(config_path = NULL, output_dir = NULL, ...)
```

## Arguments

- config_path:

  path to a config YAML used as the app's starting state; defaults to
  the shipped mock config, which runs without network access

- output_dir:

  where runs launched from the app write their output; defaults to a
  session temporary directory

- ...:

  passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html)

## Value

the value of
[`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html),
invisibly

## Details

The app runs the same
[`run_taupatch()`](https://camilleross.org/taupatch/reference/run_taupatch.md)
pipeline as a scripted run — the config it builds from the form is shown
on its Config tab, so a run driven from the GUI can be reproduced from a
config file.

## Examples

``` r
if (FALSE) { # \dontrun{
# Try the interface on synthetic data, no Copernicus credentials needed
run_taupatch_app()

# Start from a real config
run_taupatch_app("inst/configs/ctyp_gom.yaml")
} # }
```
