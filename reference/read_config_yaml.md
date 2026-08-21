# Read a config YAML without losing keys that spell a boolean

[`yaml::read_yaml()`](https://yaml.r-lib.org/reference/read_yaml.html)
parses YAML 1.1, where a bare `n` is the boolean `false`. That is
correct for a *value* and wrong for a *key*, and the difference is
silent: a derivoce step written

## Usage

``` r
read_config_yaml(path)
```

## Arguments

- path:

  path to a config YAML file

## Value

the parsed config list

## Details

    - type: lag_covariate
      vars: [CHL]
      n: 2

parses to a list whose key is named `FALSE`, so `spec$n` is `NULL` and
the step falls back to a one-month lag. The config asked for two, the
run used one, and nothing said so. The same goes for `y`, `yes`, `no`,
`on`, `off`, `true` and `false` in any capitalisation.

The fix is to keep the source text. `yaml`'s handlers are given the
original scalar as it was written — `"n"`, not `FALSE` — so this marks
each one and then, once the structure exists, restores it: text in a
name position is the key the file actually wrote, and text in a value
position becomes the logical it meant. The two cannot be told apart
while parsing, which is exactly why this is two passes rather than a
cleverer handler.

## See also

[`write_config_yaml()`](https://camilleross.org/taupatch/reference/write_config_yaml.md),
the write side —
[`yaml::as.yaml()`](https://yaml.r-lib.org/reference/as.yaml.html)
already quotes these keys on the way out, so a config this package
writes is read correctly by anything
