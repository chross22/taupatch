# Where a pipeline message places a run

Where a pipeline message places a run

## Usage

``` r
match_pipeline_stage(text)
```

## Arguments

- text:

  a message from
  [`run_taupatch()`](https://camilleross.org/taupatch/reference/run_taupatch.md)

## Value

a one-row
[`pipeline_stages()`](https://camilleross.org/taupatch/reference/pipeline_stages.md)
slice, or `NULL` for messages that are detail within a stage rather than
the start of one
