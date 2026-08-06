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
#'   `taxon`, `stage` (`NA` when the column is a total), and `name`, the column
#'   the formatted database will carry
#' @examples
#' zoop_taxa(c("CALANUS_FINMARCHICUS_10M2", "CALANUS_FINMARCHICUS_CV_10M2"))
#' @export
zoop_taxa <- function(header, suffix = "_10M2",
                      stage_pattern = "_(C(?:I{1,3}|IV|VI?))$") {
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
  staged <- grepl(stage_pattern, bare)

  taxon <- ifelse(staged, sub(stage_pattern, "", bare), bare)
  stage <- ifelse(staged, sub(paste0("^.*", stage_pattern), "\\1", bare),
                  NA_character_)

  out <- data.frame(
    column = columns,
    taxon = taxon,
    stage = stage,
    # A staged column keeps the stage on the end, because that is what the
    # `column_prefix` + `stages` machinery matches: it looks for columns
    # beginning "<prefix>_". A total carries the taxon name alone.
    name = ifelse(staged, paste0(taxon, "_", stage), taxon),
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
         "
They would overwrite one another. Rename them in the source file, ",
         "or pass a `suffix`/`stage_pattern` that tells them apart.",
         call. = FALSE)
  }

  # A stage marker somewhere other than the end was not read as the stage, so
  # the column has been treated as a total. Combination stages are how this
  # usually happens: CALANUS_FINMARCHICUS_CV_VI is neither CV nor a total.
  inner <- grepl("_C(?:I{1,3}|IV|VI?)(?:_|$)", taxa$taxon, perl = TRUE)
  if (any(inner)) {
    warning("Read as totals, but the name contains a stage marker: ",
            paste(taxa$column[inner], collapse = ", "),
            "
A combination stage such as CV_VI is neither a single stage nor ",
            "a total. Check what these columns hold before modelling them.",
            call. = FALSE)
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
            "
A config using column_prefix for one would also match the ",
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
#'   column per taxon or taxon-stage, and every other column the file carried
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
                             stage_pattern = "_(C(?:I{1,3}|IV|VI?))$",
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

  out <- split_dates(raw, column = date_column)
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
                                 stage_pattern = "_(C(?:I{1,3}|IV|VI?))$",
                                 threshold = list(type = "percentile",
                                                  value = 0.9),
                                 aliases = NULL) {
  if (is.data.frame(header)) header <- names(header)
  taxa <- zoop_taxa(header, suffix, stage_pattern)
  if (nrow(taxa) == 0) return(list())

  unique_taxa <- unique(taxa$taxon)
  keys <- stats::setNames(unique_taxa, unique_taxa)

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
#' @return a data frame of `species`, `form` (`"total"` or `"stages"`), and
#'   `stages`, one row per candidate
#' @examples
#' available_species(c("station", "year", "month", "day", "lon", "lat",
#'                     "CALANUS_FINMARCHICUS", "PSEUDOCALANUS_SPP_CIV",
#'                     "PSEUDOCALANUS_SPP_CV"))
#' @seealso [zoop_taxa()], [species_catalog_from()]
#' @export
available_species <- function(zoop_file,
                              stage_pattern = "_(C(?:I{1,3}|IV|VI?))$",
                              exclude = measurement_columns()) {
  header <- if (length(zoop_file) == 1 && file.exists(zoop_file)) {
    names(readr::read_csv(zoop_file, n_max = 0, show_col_types = FALSE,
                           progress = FALSE))
  } else {
    zoop_file
  }

  structural <- c("station", "year", "month", "day", "lon", "lat", "dataset",
                  "jday", "abundance", "patch", "TIME")
  candidates <- setdiff(header, c(structural, exclude))
  if (length(candidates) == 0) {
    return(data.frame(species = character(), form = character(),
                      stages = character(), stringsAsFactors = FALSE))
  }

  staged <- grepl(stage_pattern, candidates)
  taxon <- ifelse(staged, sub(stage_pattern, "", candidates), candidates)
  stage <- ifelse(staged, sub(paste0("^.*", stage_pattern), "\\1", candidates), NA)

  out <- do.call(rbind, lapply(unique(taxon), function(one) {
    stages <- stats::na.omit(stage[taxon == one])
    data.frame(
      species = one,
      form = if (length(stages) > 0) "stages" else "total",
      stages = paste(stages, collapse = ", "),
      stringsAsFactors = FALSE
    )
  }))
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
