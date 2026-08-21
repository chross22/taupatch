# Resolve config paths relative to the project directory

`paths.project_dir` itself is resolved relative to the config file's own
location, so a config with `project_dir: '.'` works regardless of the
caller's working directory.

## Usage

``` r
resolve_config_paths(config, config_path)
```

## Arguments

- config:

  a parsed config list

- config_path:

  path the config was read from

## Value

`config` with `paths` entries as absolute paths
