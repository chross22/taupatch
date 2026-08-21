# Check a transform against the values it will be given

Both checks need the data, so they happen where the recipe is built
rather than at config load: whether a covariate holds zeros or both
signs is not knowable from its name.

## Usage

``` r
check_transform_input(values, covariate, name, entry)
```

## Arguments

- values:

  the covariate's values

- covariate:

  the covariate's name, for the message

- name:

  the transform's name

- entry:

  the matching
  [`covariate_transforms()`](https://camilleross.org/taupatch/reference/covariate_transforms.md)
  entry

## Value

`TRUE` invisibly; errors on an undefined transform, warns on a folded
sign
