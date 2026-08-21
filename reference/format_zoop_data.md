# Build a station database from a raw zooplankton export

The raw export is not the shape the rest of this package reads. It
carries one `DATE` rather than year, month and day;
`LATITUDE`/`LONGITUDE` rather than `lat`/`lon`; and taxon columns named
for their units. This is the conversion, generalising what
`original/create_database.R` does once per taxon by hand.

## Usage

``` r
format_zoop_data(
  path,
  suffix = "_10M2",
  stage_pattern = stage_suffix_pattern(),
  date_column = "DATE",
  longitude = "LONGITUDE",
  latitude = "LATITUDE",
  write_to = NULL
)
```

## Arguments

- path:

  path to the raw CSV, or a data frame already read

- suffix:

  the units suffix marking taxon columns

- stage_pattern:

  regular expression matching a life stage; see
  [`zoop_taxa()`](https://camilleross.org/taupatch/reference/zoop_taxa.md)

- date_column:

  the column holding the sampling date

- longitude, latitude:

  the coordinate columns

- write_to:

  optional path to write the result to as CSV

## Value

a tibble with `station`, `year`, `month`, `day`, `lon`, `lat`, one
column per taxon or taxon-stage, the original date column, and every
other column the file carried

## Life stages

Some datasets resolve them and some do not, so this reads which off the
file rather than assuming. A taxon column carrying a stage keeps it —
`CALANUS_FINMARCHICUS_CV` — which is the form `column_prefix` and
`stages` match in a config. A taxon column without one is that taxon's
total and keeps the bare name, which a config reaches through
`abundance_column`.
[`species_catalog_from()`](https://camilleross.org/taupatch/reference/species_catalog_from.md)
picks the right one per taxon.

## Units

The suffix is a count and a unit, not just a unit: `_10M2` is animals
per ten square metres. The values are divided through by the number, so
what comes out is per one of whatever remains - per square metre for the
ECOMON export. The unit is recorded on the result as an `abundance_unit`
attribute rather than kept in the column names, which are then the names
of animals and nothing else.

This changes the numbers. An absolute threshold written against the raw
counts will be ten times too large once they are per square metre; a
percentile threshold is unaffected, since dividing every value by the
same number does not move a quantile.

## What it keeps

Everything. Taxon columns are renamed, the date and coordinate columns
are converted, and every other column in the file is carried through
untouched. That includes the in-situ measurements the export already
holds: `STATION_DEPTH`, `SFC_SALT`, `BTM_TEMP` and the rest. They are
not covariates. Nothing in the covariate catalog refers to them, and a
run models the gridded Copernicus fields instead. They are kept because
discarding measured values at the import step is not this function's
decision to make.

Note that the export misspells surface temperature as `SFC_TMEP`. It is
carried through as found, since silently correcting a column name would
make the output disagree with the file it came from.

## References

The export this reshapes is NOAA's Ecosystem Monitoring plankton
dataset. It is not distributed with this package and carries its own
citation:

NOAA National Marine Fisheries Service, Northeast Fisheries Science
Center. *Zooplankton and ichthyoplankton abundance and distribution in
the North Atlantic collected by the Ecosystem Monitoring (EcoMon)
Project*. NOAA National Centers for Environmental Information, NCEI
Accession 0187513. <https://www.ncei.noaa.gov/archive/accession/0187513>

## See also

[`split_dates()`](https://camilleross.org/taupatch/reference/split_dates.md),
[`zoop_taxa()`](https://camilleross.org/taupatch/reference/zoop_taxa.md),
[`species_catalog_from()`](https://camilleross.org/taupatch/reference/species_catalog_from.md)

## Examples

``` r
raw <- data.frame(
  STATION = 1:2, DATE = c("05-JAN-03", "17-JUN-11"),
  LATITUDE = c(42.1, 43.2), LONGITUDE = c(-70.1, -69.2),
  STATION_DEPTH = c(80, 120),
  CALANUS_FINMARCHICUS_10M2 = c(1200, 340),
  CENTROPAGES_TYPICUS_CV_10M2 = c(12, 40)
)
format_zoop_data(raw)
#> Dividing abundances by 10: _10M2 -> per M2
#> # A tibble: 2 × 10
#>   station  year month   day   lon   lat CALANUS_FINMARCHICUS
#>     <int> <int> <int> <int> <dbl> <dbl>                <dbl>
#> 1       1  2003     1     5 -70.1  42.1                  120
#> 2       2  2011     6    17 -69.2  43.2                   34
#> # ℹ 3 more variables: CENTROPAGES_TYPICUS_CV <dbl>, DATE <chr>,
#> #   STATION_DEPTH <dbl>
```
