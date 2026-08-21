# Split a date column into year, month, and day

The raw ECOMON export carries one `DATE` column, while the rest of this
package works in separate `year`, `month`, and `day` columns — that is
what `columns.year`/`month`/`day` name, and what the covariate matching
joins on. This is the conversion, taken from
`original/create_database.R:27-29`.

## Usage

``` r
split_dates(
  dat,
  column = "DATE",
  formats = c("%d-%b-%y", "%d-%b-%Y", "%Y-%m-%d", "%m/%d/%Y", "%m/%d/%y"),
  keep = FALSE
)
```

## Arguments

- dat:

  a data frame with a date column

- column:

  name of the date column

- formats:

  candidate `strptime` formats, tried in order; the first that parses
  every non-missing value is used. The default is the ECOMON export's
  `05-JAN-03`, followed by the usual four-digit and slash-separated
  variants.

- keep:

  whether to keep the original date column

## Value

`dat` with integer `year`, `month`, and `day` columns added

## Details

Two things the original left implicit are handled here, because both
fail quietly rather than loudly:

- `%b` matches an abbreviated month *name*, which is locale-dependent.
  Under a non-English `LC_TIME` every `05-JAN-03` parses to `NA` and the
  rows are silently dropped later as incomplete. Parsing runs under the
  C locale.

- `%y` is a two-digit year, which R maps 00–68 to the 2000s and 69–99 to
  the 1900s. That is correct for an ECOMON record running 1977 to the
  present, but it means a date can only be read as within roughly the
  last century — so a parsed date in the future is reported rather than
  accepted.

## Examples

``` r
raw <- data.frame(STATION = 1:3, DATE = c("05-JAN-03", "17-JUN-11", "28-SEP-19"))
split_dates(raw)
#>   STATION year month day
#> 1       1 2003     1   5
#> 2       2 2011     6  17
#> 3       3 2019     9  28
```
