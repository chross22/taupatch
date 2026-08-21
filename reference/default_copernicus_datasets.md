# Default Copernicus datasets

Monthly physical ocean variables from the global reanalysis: potential
temperature, salinity, and the two current components. Chlorophyll lives
in a separate biogeochemistry product and is left for the user to add,
since which BGC product is appropriate depends on the year range.

## Usage

``` r
default_copernicus_datasets()
```

## Value

a list of product/dataset/variable specs for `covariates.copernicus`
