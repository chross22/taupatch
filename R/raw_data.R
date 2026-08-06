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
