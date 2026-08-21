# Static seafloor covariates

The definitions come from
[`datamatch::bathymetry_variables()`](https://camilleross.org/datamatch/reference/bathymetry_variables.html),
which owns them so every consumer describes a covariate identically.

## Usage

``` r
bathymetry_covariates()
```

## Value

a named list, one entry per covariate, each with `label`, `units`, and
`description`

## Details

These are *static* — they do not vary by month or year — so they are
fetched once for the study area and attached to every time step, unlike
the Copernicus covariates. They replace the SRTM30 depth, slope, and
distance-to-shore layers the original model used
(`original/load_covars.R` lines 98-104), which came from a server that
no longer exists.

Fetching and attaching are
[`datamatch::fetch_bathymetry()`](https://camilleross.org/datamatch/reference/fetch_bathymetry.html)
and
[`datamatch::attach_bathymetry()`](https://camilleross.org/datamatch/reference/attach_bathymetry.html)
directly; this package only supplies the study area and cache location
from a config.

## References

NOAA National Centers for Environmental Information (2022). *ETOPO 2022
15 Arc-Second Global Relief Model*.
[doi:10.25921/fd45-gt74](https://doi.org/10.25921/fd45-gt74) — the
terrain itself;
[`datamatch::fetch_bathymetry()`](https://camilleross.org/datamatch/reference/fetch_bathymetry.html)
requests its 60 arc-second bedrock grid

Pante E, Simon-Bouhet B (2013). marmap: a package for importing,
plotting and analyzing bathymetric and topographic data in R. *PLoS ONE*
**8**(9), e73051.
[doi:10.1371/journal.pone.0073051](https://doi.org/10.1371/journal.pone.0073051)
— how it is downloaded

## Examples

``` r
names(bathymetry_covariates())
#> [1] "DEPTH"  "SLOPE"  "ASPECT" "TPI"   
```
