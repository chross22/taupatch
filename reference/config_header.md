# Header comments for a generated config

[`yaml::write_yaml()`](https://yaml.r-lib.org/reference/write_yaml.html)
writes no comments, and an uncommented config gives a reader no way in.
This is not the shipped example's per-field commentary, but it does say
what the file is and which functions list the values its fields accept.

## Usage

``` r
config_header(name)
```

## Arguments

- name:

  the config's name

## Value

a character vector of comment lines
