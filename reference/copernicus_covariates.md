# Catalog of selectable environmental covariates

The variable definitions come from
[`datamatch::copernicus_variables()`](https://camilleross.org/datamatch/reference/copernicus_variables.html),
which owns them so every consumer describes a covariate identically.
This adds the one field the pipeline needs on top: the depth range to
request.

## Usage

``` r
copernicus_covariates()
```

## Value

a named list, one entry per covariate, each with `label`, `units`,
`variable`, `product_id`, `dataset_id`, `depth`, and `description`

## Details

All entries are monthly means, matching this pipeline's monthly
timescale. Covariates sharing a dataset are fetched together in one
request.

Copernicus revises dataset identifiers periodically. If a fetch fails
with an unknown-dataset error, check the current identifier on the
Copernicus Marine Data Store
([`datamatch::product_url()`](https://camilleross.org/datamatch/reference/product_url.html)
links to the product page) and override it in the config's
`covariates.copernicus` block.

## References

Three Copernicus Marine products supply these, and a run should cite
whichever of them it fetched from. E.U. Copernicus Marine Service
Information:

*Global Ocean Physics Reanalysis* (GLORYS12V1) — `SST`, `SSS`, `BOTT`,
`UO`, `VO`, `SSH`, `MLD`, `SIC`.
[doi:10.48670/moi-00021](https://doi.org/10.48670/moi-00021)

*Global Ocean Colour* (Copernicus-GlobColour) — satellite `CHL`, `PP`,
`DIATO`, `DINO`.
[doi:10.48670/moi-00281](https://doi.org/10.48670/moi-00281)

*Global Ocean Biogeochemistry Hindcast* — `NO3`, `PO4`, `O2`, `PH`,
`CHL_MODEL`, `NPP_MODEL`.
[doi:10.48670/moi-00019](https://doi.org/10.48670/moi-00019)

Downloads go through the Copernicus Marine Toolbox
(<https://toolbox-docs.marine.copernicus.eu/>), which has no DOI of its
own — credit it by name, and cite the product.

## See also

[`datamatch::variable_dictionary()`](https://camilleross.org/datamatch/reference/variable_dictionary.html)
for the full variable listing

## Examples

``` r
names(copernicus_covariates())
#>  [1] "SST"       "SSS"       "BOTT"      "BOTS"      "UO"        "VO"       
#>  [7] "SSH"       "MLD"       "SIC"       "CHL"       "PP"        "DIATO"    
#> [13] "DINO"      "NO3"       "PO4"       "O2"        "PH"        "CHL_MODEL"
#> [19] "NPP_MODEL" "WSPD"      "UWND"      "VWND"      "TAUX"      "TAUY"     
#> [25] "TAU"      
copernicus_covariates()$SST$units
#> [1] "degrees C"
```
