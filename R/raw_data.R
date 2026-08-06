#' Split a date column into year, month, and day
#'
#' The raw ECOMON export carries one `DATE` column, while the rest of this
#' package works in separate `year`, `month`, and `day` columns — that is what
#' `columns.year`/`month`/`day` name, and what the covariate matching joins on.
#' This is the conversion, taken from `original/create_database.R:27-29`.
#'
#' Two things the original left implicit are handled here, because both fail
#' quietly rather than loudly:
#'
#' * `%b` matches an abbreviated month *name*, which is locale-dependent. Under a
#'   non-English `LC_TIME` every `05-JAN-03` parses to `NA` and the rows are
#'   silently dropped later as incomplete. Parsing runs under the C locale.
#' * `%y` is a two-digit year, which R maps 00–68 to the 2000s and 69–99 to the
#'   1900s. That is correct for an ECOMON record running 1977 to the present, but
#'   it means a date can only be read as within roughly the last century — so a
#'   parsed date in the future is reported rather than accepted.
#'
#' @param dat a data frame with a date column
#' @param column name of the date column
#' @param formats candidate `strptime` formats, tried in order; the first that
#'   parses every non-missing value is used. The default is the ECOMON export's
#'   `05-JAN-03`, followed by the usual four-digit and slash-separated variants.
#' @param keep whether to keep the original date column
#' @return `dat` with integer `year`, `month`, and `day` columns added
#' @examples
#' raw <- data.frame(STATION = 1:3, DATE = c("05-JAN-03", "17-JUN-11", "28-SEP-19"))
#' split_dates(raw)
#' @export
split_dates <- function(dat, column = "DATE",
                        formats = c("%d-%b-%y", "%d-%b-%Y", "%Y-%m-%d",
                                    "%m/%d/%Y", "%m/%d/%y"),
                        keep = FALSE) {
  if (!(column %in% names(dat))) {
    stop("No column '", column, "' in the data.\nColumns present: ",
         paste(names(dat), collapse = ", "), call. = FALSE)
  }

  values <- as.character(dat[[column]])
  parsed <- parse_dates(values, formats)

  dat$year <- as.integer(format(parsed, "%Y"))
  dat$month <- as.integer(format(parsed, "%m"))
  dat$day <- as.integer(format(parsed, "%d"))

  ahead <- !is.na(dat$year) & dat$year > as.integer(format(Sys.Date(), "%Y"))
  if (any(ahead)) {
    warning(sum(ahead), " date(s) parsed to a year in the future, e.g. ",
            values[which(ahead)[1]], " -> ", dat$year[which(ahead)[1]],
            ". A two-digit year cannot distinguish 1969 from 2069; give a ",
            "four-digit format if the record reaches that far back.",
            call. = FALSE)
  }

  if (!keep) dat[[column]] <- NULL
  dat
}

#' Parse dates against candidate formats
#'
#' Picks the first format that accounts for every non-missing value, rather than
#' the first that parses any. A format that parses most of a column and `NA`s the
#' rest is the failure mode worth catching: those rows go missing later, far from
#' the cause.
#'
#' @param values character dates
#' @param formats candidate `strptime` formats, in order
#' @return a `Date` vector
#' @keywords internal
parse_dates <- function(values, formats) {
  # %b matches month names in the current locale; the data is English.
  old_locale <- Sys.getlocale("LC_TIME")
  on.exit(Sys.setlocale("LC_TIME", old_locale), add = TRUE)
  Sys.setlocale("LC_TIME", "C")

  present <- !is.na(values) & nzchar(trimws(values))
  if (!any(present)) {
    stop("Every value in the date column is missing.", call. = FALSE)
  }

  for (format in formats) {
    parsed <- as.Date(values, format = format)
    if (all(!is.na(parsed[present]))) return(parsed)
  }

  # Report against the first format, which is the one the data is expected in.
  parsed <- as.Date(values, format = formats[1])
  failed <- present & is.na(parsed)
  stop("Could not parse ", sum(failed), " of ", sum(present), " date(s) with ",
       "any of: ", paste(formats, collapse = ", "),
       "\nFirst unparsed value(s): ",
       paste(utils::head(unique(values[failed]), 3), collapse = ", "),
       "\nPass the right format via the `formats` argument.", call. = FALSE)
}

#' The suffix marking a life stage on a taxon column
#'
#' A `C` and a Roman numeral is the core of it, but the databases in use carry
#' several more forms: a bare `C` for unstaged copepodites, `adult`, `total`, a
#' combination spanning two stages (`CV_VI`, `CI_IV`), and combinations written
#' without the `C` at all (`ctyp_IV_VI`). All are suffixes on a taxon name, and a
#' rule recognising only the first splits one taxon into several species -
#' `cfin_CV_VI` read as an animal called "cfin_CV_VI" rather than as some of
#' cfin.
#'
#' Matched without regard to case, because the databases disagree: the raw export
#' is upper case throughout, while `original/create_database.R` writes a lower
#' case taxon with an upper case stage.
#'
#' @return a regular expression with one capture group, the suffix
#' @examples
#' grepl(stage_suffix_pattern(), "cfin_CV", ignore.case = TRUE)
#' @export
stage_suffix_pattern <- function() {
  roman <- "I{1,3}|IV|VI?"
  # The leading C is optional on both halves. `ctyp_IV_VI` is a combination
  # stage written without it, and read as part of the taxon it splits one
  # animal into several.
  paste0("_(C?(?:", roman, ")(?:_C?(?:", roman, "))?|C|adult|total)$")
}

#' Conventional shorthand for a taxon name
#'
#' The genus initial and the first three letters of the species epithet, lower
#' case. `CALANUS_FINMARCHICUS` gives `cfin` and `CENTROPAGES_TYPICUS` gives
#' `ctyp`. A name with no epithet uses its first four letters.
#'
#' `Pseudocalanus` is the one exception, and is listed rather than derived: its
#' conventional shorthand is `pcal`, from the `calanus` inside the genus name,
#' which the rule above cannot produce.
#'
#' The column header remains the identity - it is what the data carries, and it
#' is matched without regard to case. This is only what a config says out loud as
#' `active:` and what the app shows in its picker.
#'
#' Two taxa can collide: `CALANUS_FINMARCHICUS` and a hypothetical
#' `CALANUS_FINLANDICUS` both give `cfin`. That is reported rather than resolved,
#' since a name invented to break the tie would be a name nobody uses.
#'
#' @param taxon taxon names, as they appear in the column header
#' @return character vector of shorthands, one per input
#' @examples
#' taxon_shorthand(c("CALANUS_FINMARCHICUS", "CENTROPAGES_TYPICUS",
#'                   "PSEUDOCALANUS_SPP", "METRIDIA_LUCENS"))
#' @export
taxon_shorthand <- function(taxon) {
  # Pseudocalanus is pcal by convention, taken from the `calanus` inside the
  # genus rather than from the epithet. The rule below cannot produce it, so it
  # is listed.
  exceptions <- c(pseudocalanus = "pcal")

  short <- vapply(taxon, function(one) {
    parts <- strsplit(tolower(one), "_", fixed = TRUE)[[1]]
    parts <- parts[nzchar(parts)]
    if (length(parts) == 0) return(tolower(one))

    known <- exceptions[parts[1]]
    if (!is.na(known)) return(unname(known))

    if (length(parts) == 1) return(substr(parts[1], 1, 4))
    paste0(substr(parts[1], 1, 1), substr(parts[2], 1, 3))
  }, character(1), USE.NAMES = FALSE)

  # One shorthand for two animals means a config naming it reaches whichever
  # came first in the catalog, silently. OITHONA_SPP and ONCAEA_SPP are the pair
  # this happens to in the ECOMON header: both give `ospp` on the rule above.
  # Three letters of the genus tells them apart - `oitspp` and `oncspp`.
  distinct <- !duplicated(tolower(taxon))
  for (one in unique(short[distinct][duplicated(short[distinct])])) {
    at <- which(short == one)

    # Three letters of the genus rather than one, then more if that is still not
    # enough. A single-word name has no epithet to draw on, so it just gets
    # longer: PSEUDOCALANIDAE and PSEUDODIAPTOMIDAE separate at the seventh
    # letter.
    resolved <- NULL
    for (extra in 0:12) {
      candidate <- vapply(taxon[at], function(name) {
        parts <- strsplit(tolower(name), "_", fixed = TRUE)[[1]]
        parts <- parts[nzchar(parts)]
        if (length(parts) == 1) return(substr(parts[1], 1, 6 + extra))
        paste0(substr(parts[1], 1, 3 + extra), substr(parts[2], 1, 3))
      }, character(1), USE.NAMES = FALSE)

      if (!anyDuplicated(candidate[!duplicated(tolower(taxon[at]))])) {
        resolved <- candidate
        break
      }
    }

    if (is.null(resolved)) {
      warning("More than one taxon shortens to '", one, "': ",
              paste(unique(taxon[at]), collapse = ", "),
              "\nNo shortening separates them. Give them explicit keys with ",
              "the `aliases` argument.", call. = FALSE)
      next
    }
    short[at] <- resolved
  }
  short
}

#' Whether a header is a raw export rather than a station database
#'
#' A raw export names its coordinates `LATITUDE`/`LONGITUDE` and carries one
#' `DATE`; a station database uses `lat`/`lon` and separate year, month and day.
#' The two are told apart by that alone, which is enough to know whether a file
#' needs [format_zoop_data()] run over it first.
#'
#' @param header column names, or a path to a CSV to read them from
#' @return `TRUE` when the file looks like a raw export
#' @examples
#' is_raw_export(c("STATION", "LATITUDE", "LONGITUDE", "DATE"))
#' is_raw_export(c("station", "lat", "lon", "year", "month", "day"))
#' @export
is_raw_export <- function(header) {
  if (length(header) == 1 && file.exists(header)) {
    header <- names(readr::read_csv(header, n_max = 0, show_col_types = FALSE,
                                     progress = FALSE))
  }
  all(c("LATITUDE", "LONGITUDE", "DATE") %in% header) &&
    !any(c("lat", "lon", "year", "month", "day") %in% header)
}

#' The count and the unit a suffix encodes
#'
#' `_10M2` is not a unit, it is a count and a unit: animals per ten square
#' metres. Splitting them is what lets abundance be reported per one of
#' something, which is the form anyone comparing two surveys needs.
#'
#' @param suffix a units suffix, with or without its leading underscore
#' @return `list(per=, unit=)`, the number the values are counted over and the
#'   unit that remains. `per` is 1 when the suffix carries no number.
#' @examples
#' abundance_units("_10M2")
#' abundance_units("_100M3")
#' @export
abundance_units <- function(suffix) {
  bare <- sub("^_", "", suffix)
  number <- regmatches(bare, regexpr("^[0-9]*\\.?[0-9]+", bare))

  list(
    per = if (length(number) == 1) as.numeric(number) else 1,
    unit = toupper(sub("^[0-9]*\\.?[0-9]+", "", bare))
  )
}

#' Taxon columns in a raw zooplankton export
#'
#' The export names every taxon column for the taxon and the units it is
#' reported in: `CALANUS_FINMARCHICUS_10M2` is abundance per 10 m². Some datasets
#' also resolve life stages, marked by a `C` and a Roman numeral —
#' `CALANUS_FINMARCHICUS_CV_10M2` is the fifth copepodite stage. A column without
#' one is the total for that taxon.
#'
#' Read off the header rather than kept as a list here. The export carries the
#' better part of a hundred taxa, gains and loses them between versions, and
#' resolves stages for some datasets and not others. A fixed list would be wrong
#' shortly after it was written.
#'
#' @param header column names, or a path to a CSV to read them from
#' @param suffix the units suffix marking an abundance column
#' @param stage_pattern regular expression matching a stage on the end of a
#'   taxon name. The default is a `C` followed by a Roman numeral one to six.
#' @return a data frame with one row per taxon column: `column` as found,
#'   `taxon`, `shorthand`, `stage` (`NA` when the column is a total), `name` (the
#'   column the formatted database will carry), and the `per`/`unit` the counts
#'   are reported in
#' @examples
#' zoop_taxa(c("CALANUS_FINMARCHICUS_10M2", "CALANUS_FINMARCHICUS_CV_10M2"))
#' @export
zoop_taxa <- function(header, suffix = "_10M2",
                      stage_pattern = stage_suffix_pattern()) {
  if (length(header) == 1 && file.exists(header)) {
    header <- names(readr::read_csv(header, n_max = 0, show_col_types = FALSE,
                                     progress = FALSE))
  }

  columns <- grep(paste0(suffix, "$"), header, value = TRUE)
  if (length(columns) == 0) {
    return(data.frame(column = character(), taxon = character(),
                      stage = character(), name = character(),
                      stringsAsFactors = FALSE))
  }

  bare <- sub(paste0(suffix, "$"), "", columns)
  staged <- grepl(stage_pattern, bare, ignore.case = TRUE)

  # One match, used for both halves. Extracting the suffix with a greedy "^.*"
  # in front of it finds the *rightmost* match while sub() strips the leftmost,
  # so the two disagree the moment a suffix can match in two places -
  # CALANUS_FINMARCHICUS_CV_VI reads as stage VI of a taxon ending in CV.
  taxon <- ifelse(staged, sub(stage_pattern, "", bare, ignore.case = TRUE), bare)
  # By position, since sub() takes one pattern and there is one per row.
  found <- ifelse(staged, substring(bare, nchar(taxon) + 2), NA_character_)

  # `total` is a suffix that identifies the taxon but is not a stage: the column
  # is that taxon's total, which is what a stage-less column already is.
  is_total <- !is.na(found) & tolower(found) == "total"
  # Upper case, so the codes line up with single_stages() whichever case the
  # database wrote them in.
  stage <- ifelse(is_total, NA_character_, toupper(found))

  units <- abundance_units(suffix)
  warn_mixed_units(header, suffix)

  out <- data.frame(
    column = columns,
    taxon = taxon,
    shorthand = taxon_shorthand(taxon),
    stage = stage,
    # A staged column keeps the stage on the end, because that is what the
    # `column_prefix` + `stages` machinery matches: it looks for columns
    # beginning "<prefix>_". A total carries the taxon name alone.
    # The suffix is kept whatever it was, including `total`, so two columns of
    # one taxon never collapse onto one name.
    name = ifelse(staged, paste0(taxon, "_", ifelse(is_total, found, stage)),
                  taxon),
    per = units$per,
    unit = units$unit,
    stringsAsFactors = FALSE
  )

  warn_ambiguous_taxa(out, stage_pattern)
  out
}

#' Warn about taxon names this cannot read confidently
#'
#' Every rule for reading a taxon out of a column name is a guess about how the
#' export was written, and the guesses fail quietly: a column read as a total
#' when it is really a stage still produces a plausible number. These are the
#' three ways it goes wrong that can be spotted from the names alone.
#'
#' @param taxa a [zoop_taxa()] table
#' @param stage_pattern the pattern used to find stages
#' @return `taxa`, invisibly; warns or errors as appropriate
#' @keywords internal
warn_ambiguous_taxa <- function(taxa, stage_pattern) {
  # Two source columns landing on one output column would silently overwrite
  # each other, so this is an error rather than a warning.
  duplicated_names <- unique(taxa$name[duplicated(taxa$name)])
  if (length(duplicated_names) > 0) {
    clashing <- taxa$column[taxa$name %in% duplicated_names]
    stop("These columns resolve to the same name: ",
         paste(clashing, collapse = ", "),
         "\nThey would overwrite one another. Rename them in the source file, ",
         "or pass a `suffix`/`stage_pattern` that tells them apart.",
         call. = FALSE)
  }

  # A stage marker somewhere other than the end of the name could not be
  # separated from the taxon, so the column has been read as a total.
  inner <- grepl("_C(?:I{1,3}|IV|VI?)_(?!C?(?:I{1,3}|IV|VI?)$)", taxa$taxon,
                 perl = TRUE, ignore.case = TRUE)
  if (any(inner)) {
    warning("Read as totals, but the name contains a stage marker: ",
            paste(taxa$column[inner], collapse = ", "),
            "\nThe stage was not on the end of the name, so it could not be ",
            "told apart from the taxon. Check what these columns hold.",
            call. = FALSE)
  }

  # Two spellings of one taxon are two species to everything downstream, and
  # the difference is easy to miss in an alphabetically sorted dropdown.
  folded <- tolower(taxa$taxon)
  for (one in unique(folded[duplicated(folded)])) {
    spellings <- unique(taxa$taxon[folded == one])
    if (length(spellings) > 1) {
      warning("One taxon spelled more than one way: ",
              paste(spellings, collapse = ", "),
              "\nStages are matched without regard to case, but the taxon name ",
              "is kept as written, so these appear as separate species.",
              call. = FALSE)
    }
  }

  # `column_prefix` matches "<prefix>_", so a taxon whose name prefixes another
  # would collect the other's stage columns as if they were its own.
  unique_taxa <- unique(taxa$taxon)
  shadowed <- vapply(unique_taxa, function(one) {
    any(startsWith(setdiff(unique_taxa, one), paste0(one, "_")))
  }, logical(1))
  if (any(shadowed)) {
    warning("These taxon names are prefixes of others: ",
            paste(unique_taxa[shadowed], collapse = ", "),
            "\nA config using column_prefix for one would also match the ",
            "other's columns. Use abundance_column for them, or rename.",
            call. = FALSE)
  }

  invisible(taxa)
}

#' Build a station database from a raw zooplankton export
#'
#' The raw export is not the shape the rest of this package reads. It carries one
#' `DATE` rather than year, month and day; `LATITUDE`/`LONGITUDE` rather than
#' `lat`/`lon`; and taxon columns named for their units. This is the conversion,
#' generalising what `original/create_database.R` does once per taxon by hand.
#'
#' @section Life stages:
#' Some datasets resolve them and some do not, so this reads which off the file
#' rather than assuming. A taxon column carrying a stage keeps it —
#' `CALANUS_FINMARCHICUS_CV` — which is the form `column_prefix` and `stages`
#' match in a config. A taxon column without one is that taxon's total and keeps
#' the bare name, which a config reaches through `abundance_column`.
#' [species_catalog_from()] picks the right one per taxon.
#'
#' @section Units:
#' The suffix is a count and a unit, not just a unit: `_10M2` is animals per ten
#' square metres. The values are divided through by the number, so what comes out
#' is per one of whatever remains - per square metre for the ECOMON export. The
#' unit is recorded on the result as an `abundance_unit` attribute rather than
#' kept in the column names, which are then the names of animals and nothing
#' else.
#'
#' This changes the numbers. An absolute threshold written against the raw
#' counts will be ten times too large once they are per square metre; a
#' percentile threshold is unaffected, since dividing every value by the same
#' number does not move a quantile.
#'
#' @section What it keeps:
#' Everything. Taxon columns are renamed, the date and coordinate columns are
#' converted, and every other column in the file is carried through untouched.
#' That includes the in-situ measurements the export already holds:
#' `STATION_DEPTH`, `SFC_SALT`, `BTM_TEMP` and the rest. They are not covariates.
#' Nothing in the covariate catalog refers to them, and a run models the gridded
#' Copernicus fields instead. They are kept because discarding measured values at
#' the import step is not this function's decision to make.
#'
#' Note that the export misspells surface temperature as `SFC_TMEP`. It is
#' carried through as found, since silently correcting a column name would make
#' the output disagree with the file it came from.
#'
#' @param path path to the raw CSV, or a data frame already read
#' @param suffix the units suffix marking taxon columns
#' @param stage_pattern regular expression matching a life stage; see [zoop_taxa()]
#' @param date_column the column holding the sampling date
#' @param longitude,latitude the coordinate columns
#' @param write_to optional path to write the result to as CSV
#' @return a tibble with `station`, `year`, `month`, `day`, `lon`, `lat`, one
#'   column per taxon or taxon-stage, the original date column, and every other
#'   column the file carried
#' @examples
#' raw <- data.frame(
#'   STATION = 1:2, DATE = c("05-JAN-03", "17-JUN-11"),
#'   LATITUDE = c(42.1, 43.2), LONGITUDE = c(-70.1, -69.2),
#'   STATION_DEPTH = c(80, 120),
#'   CALANUS_FINMARCHICUS_10M2 = c(1200, 340),
#'   CENTROPAGES_TYPICUS_CV_10M2 = c(12, 40)
#' )
#' format_zoop_data(raw)
#' @seealso [split_dates()], [zoop_taxa()], [species_catalog_from()]
#' @export
format_zoop_data <- function(path, suffix = "_10M2",
                             stage_pattern = stage_suffix_pattern(),
                             date_column = "DATE",
                             longitude = "LONGITUDE", latitude = "LATITUDE",
                             write_to = NULL) {
  raw <- if (is.data.frame(path)) {
    path
  } else {
    readr::read_csv(path, show_col_types = FALSE, progress = FALSE)
  }

  missing <- setdiff(c(date_column, longitude, latitude), names(raw))
  if (length(missing) > 0) {
    stop("Column(s) not found in the raw data: ", paste(missing, collapse = ", "),
         "\nColumns present: ", paste(names(raw), collapse = ", "), call. = FALSE)
  }

  taxa <- zoop_taxa(names(raw), suffix, stage_pattern)
  if (nrow(taxa) == 0) {
    stop("No taxon columns found: nothing in the file ends in '", suffix, "'.\n",
         "Pass `suffix` if this export reports abundance in other units.",
         call. = FALSE)
  }

  # Reported per ten square metres, or per whatever the suffix says. Divided
  # through so the values are per one of it, which is the only form in which two
  # surveys counted over different areas can be compared.
  units <- abundance_units(suffix)
  if (units$per != 1) {
    message("Dividing abundances by ", units$per, ": ", suffix, " -> per ",
            units$unit)
    for (column in taxa$column) {
      raw[[column]] <- raw[[column]] / units$per
    }
  }

  # Kept, not consumed. The date is the only column that says what a station
  # actually recorded; year, month and day are a convenience derived from it,
  # and throwing the original away makes the derivation unverifiable.
  out <- split_dates(raw, column = date_column, keep = TRUE)
  names(out)[match(longitude, names(out))] <- "lon"
  names(out)[match(latitude, names(out))] <- "lat"
  names(out)[match(taxa$column, names(out))] <- taxa$name
  if ("STATION" %in% names(out)) {
    names(out)[names(out) == "STATION"] <- "station"
  }

  # The columns the rest of the package looks for, first and in a fixed order,
  # then the taxa, then whatever else the export carried.
  leading <- intersect(c("station", "year", "month", "day", "lon", "lat"),
                       names(out))
  out <- out[c(leading, taxa$name,
               setdiff(names(out), c(leading, taxa$name)))]
  out <- tibble::as_tibble(out)
  # Recorded rather than encoded in the column names, so the names stay the
  # names of animals.
  attr(out, "abundance_unit") <- units$unit

  if (!is.null(write_to)) {
    dir.create(dirname(write_to), recursive = TRUE, showWarnings = FALSE)
    readr::write_csv(out, write_to)
  }
  out
}

#' A species catalog for the taxa in a raw export
#'
#' Writes the `species.catalog` block a config needs, one entry per taxon.
#' Suitable for passing to [generate_config()] as `species`.
#'
#' Which form an entry takes depends on the file. A taxon whose stages the
#' dataset resolves gets `column_prefix`, so a run can select stages or leave
#' them out to sum every one. A taxon reported only as a total gets
#' `abundance_column`, because there is no prefix for anything to match.
#'
#' A taxon carrying both a total and some stages gets the prefix form, and the
#' bare total column is then not read: `column_prefix` matches only
#' `<taxon>_<something>`, which is what keeps the total from being summed
#' alongside the stages that compose it. Worth knowing that summing the resolved
#' stages need not reproduce the reported total, since a dataset may resolve only
#' some of them. Use `abundance_column` explicitly if the total is what you
#' want.
#'
#' @param header column names, a raw export, or a path to one
#' @param suffix the units suffix marking taxon columns
#' @param stage_pattern regular expression matching a life stage
#' @param threshold the threshold every entry gets
#' @param aliases optional named character vector giving short config keys to
#'   taxa, e.g. `c(cfin = "CALANUS_FINMARCHICUS")`
#' @return a named list suitable for `species.catalog`
#' @examples
#' header <- c("CALANUS_FINMARCHICUS_CV_10M2", "CALANUS_FINMARCHICUS_CVI_10M2",
#'             "CENTROPAGES_TYPICUS_10M2")
#'
#' # cfin resolves stages here, so it gets a prefix; ctyp is a total.
#' species_catalog_from(header, aliases = c(cfin = "CALANUS_FINMARCHICUS"))
#' @seealso [format_zoop_data()], [generate_config()]
#' @export
species_catalog_from <- function(header, suffix = "_10M2",
                                 stage_pattern = stage_suffix_pattern(),
                                 threshold = list(type = "percentile",
                                                  value = 0.9),
                                 aliases = NULL) {
  if (is.data.frame(header)) header <- names(header)
  taxa <- zoop_taxa(header, suffix, stage_pattern)
  if (nrow(taxa) == 0) return(list())

  unique_taxa <- unique(taxa$taxon)
  # Keyed by the conventional shorthand, pointing at the column header name.
  # The header stays the identity; the key is only what a config says out loud.
  keys <- stats::setNames(unique_taxa, taxon_shorthand(unique_taxa))

  if (!is.null(aliases)) {
    unknown <- setdiff(unname(aliases), unique_taxa)
    if (length(unknown) > 0) {
      stop("Alias(es) point at taxa that are not in the data: ",
           paste(unknown, collapse = ", "),
           "\nPresent: ", paste(unique_taxa, collapse = ", "), call. = FALSE)
    }
    keys <- keys[!(keys %in% unname(aliases))]
    keys <- c(stats::setNames(unname(aliases), names(aliases)), keys)
  }

  entries <- lapply(unname(keys), function(taxon) {
    staged <- any(taxa$taxon == taxon & !is.na(taxa$stage))
    if (staged) {
      list(column_prefix = taxon, threshold = threshold)
    } else {
      list(abundance_column = taxon, threshold = threshold)
    }
  })
  stats::setNames(entries, names(keys))
}

#' Species a formatted database could model
#'
#' The config's species catalog names the taxa a run was set up for. A formatted
#' export carries every taxon the survey counted, which is most of a hundred, and
#' any of them can be modelled. This reads the candidates off the file.
#'
#' A taxon with stage columns is reported once, as a prefix, since that is how a
#' config selects it and how its stages are summed. Everything else is reported
#' as a total.
#'
#' @section What it cannot tell you:
#' A formatted database has had the units cut off its taxon columns, so nothing
#' in the name distinguishes a taxon from the in-situ measurements the export
#' also carries. `STATION_DEPTH` and `BTM_TEMP` are candidates here in exactly
#' the way `CALANUS_FINMARCHICUS` is. The list is what could be an abundance
#' column, not what is one. Run [zoop_taxa()] against the raw export for the
#' answer the raw column names still hold.
#'
#' @param zoop_file path to a formatted database, or its column names
#' @param stage_pattern regular expression matching a life stage
#' @param exclude columns to leave out. The default drops the in-situ
#'   measurements the ECOMON export carries, which are numeric columns that are
#'   not taxa; pass `character()` to see them.
#' @return a data frame of `species` (the column header name), `shorthand`,
#'   `form` (`"total"` or `"stages"`), and `stages`, one row per candidate
#' @examples
#' available_species(c("station", "year", "month", "day", "lon", "lat",
#'                     "CALANUS_FINMARCHICUS", "PSEUDOCALANUS_SPP_CIV",
#'                     "PSEUDOCALANUS_SPP_CV"))
#' @seealso [zoop_taxa()], [species_catalog_from()]
#' @export
available_species <- function(zoop_file,
                              stage_pattern = stage_suffix_pattern(),
                              exclude = measurement_columns()) {
  header <- if (length(zoop_file) == 1 && file.exists(zoop_file)) {
    names(readr::read_csv(zoop_file, n_max = 0, show_col_types = FALSE,
                           progress = FALSE))
  } else {
    zoop_file
  }

  # DATE is kept by format_zoop_data() as the source of year/month/day, so it
  # is in a formatted file and is not an animal.
  # A raw export says outright which columns are taxa: they are the ones ending
  # in a count and a unit. Nothing else is, whatever it is called. Use that
  # rather than guessing, since guessing is what puts DATE and STATION in a list
  # of animals.
  if (is_raw_export(header)) {
    taxa <- zoop_taxa(header, suffix = raw_abundance_suffix(header),
                      stage_pattern = stage_pattern)
    if (nrow(taxa) == 0) {
      return(data.frame(species = character(), shorthand = character(),
                        form = character(), stages = character(),
                        stringsAsFactors = FALSE))
    }
    out <- do.call(rbind, lapply(unique(taxa$taxon), function(one) {
      stages <- stats::na.omit(taxa$stage[taxa$taxon == one])
      data.frame(species = one,
                 shorthand = taxon_shorthand(one),
                 form = if (length(stages) > 0) "stages" else "total",
                 stages = paste(stages, collapse = ", "),
                 stringsAsFactors = FALSE)
    }))
    return(out[order(out$species), ])
  }

  # A formatted database has had the suffix cut off, so the rule above is gone
  # and only the exclusions are left.
  structural <- c("station", "year", "month", "day", "lon", "lat", "dataset",
                  "jday", "abundance", "patch", "TIME", "DATE", "date")
  candidates <- setdiff(header, c(structural, exclude))
  if (length(candidates) == 0) {
    return(data.frame(species = character(), form = character(),
                      stages = character(), stringsAsFactors = FALSE))
  }

  staged <- grepl(stage_pattern, candidates, ignore.case = TRUE)
  taxon <- ifelse(staged, sub(stage_pattern, "", candidates, ignore.case = TRUE),
                  candidates)
  # Derived from the taxon rather than matched again, so the two cannot disagree.
  found <- ifelse(staged, substring(candidates, nchar(taxon) + 2), NA_character_)
  # A total is the taxon, not one of its stages, so it groups the columns
  # without being offered as something to select.
  stage <- ifelse(!is.na(found) & tolower(found) == "total", NA_character_,
                  toupper(found))

  out <- do.call(rbind, lapply(unique(taxon), function(one) {
    stages <- stats::na.omit(stage[taxon == one])
    data.frame(
      species = one,
      shorthand = taxon_shorthand(one),
      form = if (length(stages) > 0) "stages" else "total",
      stages = paste(stages, collapse = ", "),
      stringsAsFactors = FALSE
    )
  }))
  out$shorthand <- taxon_shorthand(out$species)
  out[order(out$species), ]
}

#' In-situ measurement columns the raw export carries
#'
#' A formatted database has had the units cut off its taxon columns, so nothing
#' in a name distinguishes `CALANUS_FINMARCHICUS` from `BTM_TEMP`. These are the
#' measurement columns the ECOMON export is known to carry, so that a list of
#' modellable species is not padded with water temperature.
#'
#' A list rather than a rule, because there is no rule: the export names its
#' measurements no differently from its animals. Anything not here and not
#' structural is taken to be a taxon.
#'
#' `SFC_TMEP` is in the list twice over, spelled as the export spells it and as
#' it would be spelled correctly, so a file that has since been fixed is still
#' handled.
#'
#' @return character vector of column names
#' @examples
#' measurement_columns()
#' @export
measurement_columns <- function() {
  c("CRUISE_NAME", "EVENT_PK_SEQ", "NET_PK_SEQ", "ZOO_GEAR", "TOW_PROTOCOL",
    "TOW_PROFILE", "SORT_TYPE", "STATION_DEPTH", "SFC_TMEP", "SFC_TEMP",
    "SFC_SALT", "BTM_TEMP", "BTM_SALT", "BIO_VOLUME_1M2")
}

#' Warn when a header carries more than one abundance unit
#'
#' Only columns ending in the chosen suffix are read as taxa, so a column
#' reported in some other unit is not converted, not renamed, and not modelled.
#' It is carried through as though it were a measurement, which looks exactly
#' like a taxon that simply was not counted.
#'
#' Worth catching for a second reason. Per square metre is an areal density,
#' integrated through the water column; per cubic metre is a concentration at
#' depth. Dividing each by its own number puts both "per one", but per m2 and
#' per m3 remain different quantities, and one cannot be turned into the other
#' without knowing the depth the tow integrated over. Two surveys reported in the
#' two units cannot be pooled on the strength of both saying "per one".
#'
#' @param header the file's column names
#' @param suffix the suffix being read as taxa
#' @return `NULL`, invisibly; warns when others are present
#' @keywords internal
warn_mixed_units <- function(header, suffix) {
  # Anything ending in a count and a metre unit is an abundance column.
  others <- grep("_[0-9]*\\.?[0-9]*M[23]$", header, value = TRUE,
                 ignore.case = TRUE)
  others <- others[!grepl(paste0(suffix, "$"), others, ignore.case = TRUE)]
  if (length(others) == 0) return(invisible(NULL))

  found <- unique(sub("^.*(_[0-9]*\\.?[0-9]*M[23])$", "\\1", others,
                      ignore.case = TRUE))
  warning("Columns in other units were not read as taxa: ",
          paste(utils::head(others, 4), collapse = ", "),
          if (length(others) > 4) ", ..." else "",
          "\nReading '", suffix, "', but the file also has ",
          paste(found, collapse = ", "),
          ".\nRun format_zoop_data() once per unit. Per m2 and per m3 are not ",
          "interconvertible without the depth the tow integrated over, so the ",
          "two cannot be pooled.", call. = FALSE)
  invisible(NULL)
}

#' The abundance suffix a raw export uses
#'
#' Read off the header rather than assumed, so a file counting per 100 cubic
#' metres is handled without being told. The most common suffix wins when a file
#' carries more than one, which `warn_mixed_units()` reports separately.
#'
#' @param header the file's column names
#' @return the suffix, including its leading underscore; `"_10M2"` when the
#'   header has none, since that is what the ECOMON export uses
#' @examples
#' raw_abundance_suffix(c("STATION", "CALANUS_FINMARCHICUS_100M3"))
#' @export
raw_abundance_suffix <- function(header) {
  found <- regmatches(header, regexpr("_[0-9]*\\.?[0-9]*M[23]$", header,
                                      ignore.case = TRUE))
  if (length(found) == 0) return("_10M2")
  names(sort(table(toupper(found)), decreasing = TRUE))[1]
}
