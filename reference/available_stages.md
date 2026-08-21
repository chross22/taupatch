# List the life stages a database holds for a species

Reads the available stages off the data rather than assuming a fixed
set, because the database's stage columns differ per species: `cfin`
resolves `CI` through `CVI`, while `ctyp` and `pseudo` carry `adult` and
only some copepodite stages. A hardcoded list would offer stages that do
not exist for a given species.

## Usage

``` r
available_stages(zoop_file, column_prefix, single_only = TRUE)
```

## Arguments

- zoop_file:

  path to the zooplankton database CSV

- column_prefix:

  the species' column prefix in the database, e.g. `"pseudo"`

- single_only:

  when `TRUE` (the default), lists only individually resolved stages
  (see
  [`single_stages()`](https://camilleross.org/taupatch/reference/single_stages.md));
  when `FALSE`, also lists the overlapping combination columns

## Value

character vector of stage codes, e.g. `c("CI", "CII", "adult")`

## Examples

``` r
if (FALSE) { # \dontrun{
available_stages("data/zooplankton_database.csv", "cfin")
#> "CI" "CII" "CIII" "CIV" "CV" "CVI"
available_stages("data/zooplankton_database.csv", "ctyp")
#> "CIII" "CIV" "CV" "CVI" "adult"
} # }
```
