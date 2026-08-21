# The stages a run passes through, and how far along each one is

[`run_taupatch()`](https://camilleross.org/taupatch/reference/run_taupatch.md)
announces each stage as it starts. This turns those announcements into a
position on a progress bar, so a caller watching a long run can tell a
covariate download from a model fit.

## Usage

``` r
pipeline_stages()
```

## Value

a data frame of `pattern`, `label`, and `at` (fraction complete when the
stage starts), in order

## Details

The fractions are where a stage *begins*, and they are weighted by how
long each takes rather than spread evenly: fetching covariates is most
of a real run and labelling patches is instant, so an even split would
sit at 40% for twenty minutes and then race through the rest.

Matched on the message rather than signalled through a condition class,
because the messages are the pipeline's existing interface to anyone
watching it and a second channel would be a second thing to keep in
step.

## Examples

``` r
pipeline_stages()
#>                                  pattern                                  label
#> 1              ^Loading zooplankton data           Reading the station database
#> 2     ^Fetching environmental covariates Downloading covariates from Copernicus
#> 3  ^Preparing covariates before the join  Resampling covariates before the join
#> 4                   ^Fetching bathymetry                 Downloading bathymetry
#> 5                   ^Deriving covariates           Computing derived covariates
#> 6       ^Matching covariates to stations        Matching covariates to stations
#> 7             ^Attaching climate indices              Attaching climate indices
#> 8                      ^Labeling patches       Labelling high-abundance patches
#> 9                ^Jackknifing covariates        Testing covariates by jackknife
#> 10                        ^Fitting model Fitting and cross-validating the model
#> 11       ^Projecting monthly suitability                Projecting monthly maps
#> 12                    ^Output written to                         Writing output
#>      at
#> 1  0.02
#> 2  0.06
#> 3  0.55
#> 4  0.60
#> 5  0.64
#> 6  0.72
#> 7  0.76
#> 8  0.78
#> 9  0.79
#> 10 0.86
#> 11 0.94
#> 12 0.99
```
