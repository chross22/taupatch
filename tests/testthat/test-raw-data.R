test_that("the ECOMON export's date format is split into year, month, day", {
  raw <- data.frame(STATION = 1:3,
                    DATE = c("05-JAN-03", "17-JUN-11", "28-SEP-19"))

  out <- split_dates(raw)

  expect_equal(out$year, c(2003L, 2011L, 2019L))
  expect_equal(out$month, c(1L, 6L, 9L))
  expect_equal(out$day, c(5L, 17L, 28L))
  expect_false("DATE" %in% names(out))
  expect_true("DATE" %in% names(split_dates(raw, keep = TRUE)))
})

test_that("two-digit years before the cutoff read as the 1900s", {
  # ECOMON runs back to 1977, so this is the live half of the rule rather than
  # a hypothetical: %y maps 69-99 to the 1900s and 00-68 to the 2000s.
  out <- split_dates(data.frame(DATE = c("14-MAR-77", "14-MAR-99", "14-MAR-00")))

  expect_equal(out$year, c(1977L, 1999L, 2000L))
})

test_that("month names parse regardless of the session locale", {
  # %b matches month names in LC_TIME. Under a non-English locale every date
  # NAs out, and the rows disappear much later as incomplete records.
  skip_on_cran()
  old <- Sys.getlocale("LC_TIME")
  if (is.na(suppressWarnings(Sys.setlocale("LC_TIME", "fr_FR.UTF-8")))) {
    skip("no French locale available to test against")
  }
  on.exit(Sys.setlocale("LC_TIME", old), add = TRUE)

  out <- split_dates(data.frame(DATE = c("05-JAN-03", "17-JUN-11")))

  expect_equal(out$year, c(2003L, 2011L))
  expect_equal(out$month, c(1L, 6L))
  # The locale is left as it was found.
  expect_equal(Sys.getlocale("LC_TIME"), "fr_FR.UTF-8")
})

test_that("other common date formats are recognized", {
  expect_equal(split_dates(data.frame(DATE = "2003-01-05"))$year, 2003L)
  expect_equal(split_dates(data.frame(DATE = "01/05/2003"))$month, 1L)
  expect_equal(split_dates(data.frame(DATE = "05-JAN-2003"))$day, 5L)
})

test_that("a format that parses only part of the column is not accepted", {
  # The failure worth catching: a format that works on most rows and NAs the
  # rest, so the bad rows vanish later rather than erroring here.
  raw <- data.frame(DATE = c("05-JAN-03", "17-JUN-11", "not a date"))

  expect_error(split_dates(raw), "Could not parse 1 of 3")
  expect_error(split_dates(raw), "not a date")
})

test_that("missing values are allowed but an all-missing column is not", {
  out <- split_dates(data.frame(DATE = c("05-JAN-03", NA)))
  expect_equal(out$year, c(2003L, NA_integer_))

  expect_error(split_dates(data.frame(DATE = c(NA, NA))), "Every value")
})

test_that("a missing date column names the columns that are present", {
  expect_error(split_dates(data.frame(STATION = 1, SAMPLE_DATE = "05-JAN-03")),
               "No column 'DATE'")
  expect_error(split_dates(data.frame(STATION = 1, SAMPLE_DATE = "05-JAN-03")),
               "SAMPLE_DATE")

  expect_equal(
    split_dates(data.frame(SAMPLE_DATE = "05-JAN-03"), column = "SAMPLE_DATE")$year,
    2003L
  )
})

test_that("a date read into the future is reported", {
  # 69-99 mapping to the 1900s is the useful half; the other edge is that a
  # genuinely old two-digit year cannot be told from a future one.
  expect_warning(split_dates(data.frame(DATE = "01-JAN-60"), formats = "%d-%b-%y"),
                 "future")
})

# A raw export in the shape the ECOMON file arrives in, including its misspelled
# surface temperature column.
raw_export <- function(staged = FALSE) {
  out <- data.frame(
    CRUISE_NAME = c("EC1801", "EC1802"), STATION = c(1L, 2L),
    LATITUDE = c(42.1, 43.2), LONGITUDE = c(-70.1, -69.2),
    DATE = c("05-JAN-03", "17-JUN-11"), TIME = c("12:00:00", "03:30:00"),
    STATION_DEPTH = c(80, 120), SFC_TMEP = c(6.1, 12.4),
    BTM_TEMP = c(5.0, 6.2),
    CALANUS_FINMARCHICUS_10M2 = c(1200, 340),
    CENTROPAGES_TYPICUS_10M2 = c(50, 900),
    stringsAsFactors = FALSE
  )
  if (staged) {
    out$PSEUDOCALANUS_SPP_CIV_10M2 <- c(20, 15)
    out$PSEUDOCALANUS_SPP_CV_10M2 <- c(30, 25)
  }
  out
}

test_that("taxon columns are split into taxon and stage", {
  taxa <- zoop_taxa(c("CALANUS_FINMARCHICUS_10M2", "CALANUS_FINMARCHICUS_CV_10M2",
                      "PSEUDOCALANUS_SPP_CIII_10M2", "STATION"))

  expect_equal(nrow(taxa), 3)
  expect_equal(taxa$taxon,
               c("CALANUS_FINMARCHICUS", "CALANUS_FINMARCHICUS", "PSEUDOCALANUS_SPP"))
  # A column with no stage marker is that taxon's total.
  expect_equal(taxa$stage, c(NA, "CV", "CIII"))
  # A staged column keeps the stage, because that is the form column_prefix
  # matches; a total keeps the bare taxon name.
  expect_equal(taxa$name, c("CALANUS_FINMARCHICUS", "CALANUS_FINMARCHICUS_CV",
                            "PSEUDOCALANUS_SPP_CIII"))
})

test_that("every copepodite stage is recognized and nothing else is", {
  staged <- paste0("TAXON_", c("CI", "CII", "CIII", "CIV", "CV", "CVI"), "_10M2")
  expect_equal(zoop_taxa(staged)$stage, c("CI", "CII", "CIII", "CIV", "CV", "CVI"))
  expect_true(all(zoop_taxa(staged)$taxon == "TAXON"))

  # A taxon whose name merely ends in a capital is not a stage.
  expect_true(is.na(zoop_taxa("CALANUS_SPP_10M2")$stage))
  expect_true(is.na(zoop_taxa("PARAEUCHAETA_NORVEGICA_10M2")$stage))
})

test_that("a raw export is reshaped into what the pipeline reads", {
  out <- format_zoop_data(raw_export())

  # The columns load_zoop_data() declares, in a predictable order.
  expect_equal(names(out)[1:6],
               c("station", "year", "month", "day", "lon", "lat"))
  expect_equal(out$year, c(2003L, 2011L))
  expect_equal(out$lon, c(-70.1, -69.2))

  # Taxa named for the animal, with the units cut off.
  expect_true(all(c("CALANUS_FINMARCHICUS", "CENTROPAGES_TYPICUS") %in% names(out)))
  expect_equal(out$CALANUS_FINMARCHICUS, c(1200, 340))
  expect_false(any(grepl("10M2", names(out))))
})

test_that("everything else in the file is carried through untouched", {
  out <- format_zoop_data(raw_export())

  # The in-situ measurements are kept. They are not covariates, but discarding
  # measured values at the import step is not this function's call.
  expect_true(all(c("STATION_DEPTH", "BTM_TEMP", "TIME", "CRUISE_NAME") %in%
                    names(out)))
  # Including the export's own misspelling, which is corrected nowhere.
  expect_true("SFC_TMEP" %in% names(out))
  expect_equal(out$STATION_DEPTH, c(80, 120))
})

test_that("the formatted database loads back through the pipeline", {
  dir <- tempfile("raw"); dir.create(dir)
  path <- file.path(dir, "formatted.csv")
  format_zoop_data(raw_export(), write_to = path)

  config <- mock_config()
  config$paths$zoop_file <- path
  config$columns$dataset_filter <- NULL
  config$dates$years <- c(2003, 2011)
  config$dates$months <- c(1, 12)
  config$study_area$bbox <- list(xmin = -71, xmax = -69, ymin = 42, ymax = 44)
  config$species$catalog <- species_catalog_from(names(raw_export()),
                                                  aliases = c(cfin = "CALANUS_FINMARCHICUS"))
  config$species$active <- "cfin"
  config$species$resolved <- resolve_species(config)

  # The whole point: a formatted export is a database load_zoop_data() reads.
  expect_true(validate_columns(config))
  dat <- load_zoop_data(config)
  expect_equal(nrow(dat), 2)
  expect_equal(sort(dat$abundance), c(340, 1200))
})

test_that("the catalog form follows whether the dataset resolves stages", {
  unstaged <- species_catalog_from(names(raw_export()))
  # A total-only taxon has no prefix for anything to match.
  expect_equal(unstaged$CALANUS_FINMARCHICUS$abundance_column,
               "CALANUS_FINMARCHICUS")
  expect_null(unstaged$CALANUS_FINMARCHICUS$column_prefix)

  staged <- species_catalog_from(names(raw_export(staged = TRUE)))
  expect_equal(staged$PSEUDOCALANUS_SPP$column_prefix, "PSEUDOCALANUS_SPP")
  expect_null(staged$PSEUDOCALANUS_SPP$abundance_column)
  # The unstaged taxa in the same file keep their own form.
  expect_equal(staged$CENTROPAGES_TYPICUS$abundance_column, "CENTROPAGES_TYPICUS")
})

test_that("a staged taxon resolves its stages through the existing machinery", {
  dir <- tempfile("raw"); dir.create(dir)
  path <- file.path(dir, "staged.csv")
  format_zoop_data(raw_export(staged = TRUE), write_to = path)

  expect_setequal(available_stages(path, "PSEUDOCALANUS_SPP"), c("CIV", "CV"))

  config <- mock_config()
  config$paths$zoop_file <- path
  config$columns$dataset_filter <- NULL
  config$species$catalog <- species_catalog_from(names(raw_export(staged = TRUE)))
  config$species$active <- "PSEUDOCALANUS_SPP"
  config$species$catalog$PSEUDOCALANUS_SPP$stages <- "CV"
  config$species$resolved <- resolve_species(config)
  config$dates$years <- c(2003, 2011); config$dates$months <- c(1, 12)
  config$study_area$bbox <- list(xmin = -71, xmax = -69, ymin = 42, ymax = 44)

  dat <- load_zoop_data(config)
  # Only the requested stage, not the sum of both.
  expect_setequal(dat$abundance, c(30, 25))
})

test_that("aliases must name taxa the file has", {
  expect_error(
    species_catalog_from(names(raw_export()), aliases = c(cfin = "CALANUS_NOPE")),
    "not in the data"
  )
})

test_that("a file with no taxon columns says so", {
  raw <- raw_export()
  raw <- raw[, !grepl("10M2", names(raw))]

  expect_error(format_zoop_data(raw), "No taxon columns found")
  expect_error(format_zoop_data(raw), "suffix")
})

test_that("missing structural columns are reported against what is present", {
  raw <- raw_export()
  raw$LATITUDE <- NULL

  expect_error(format_zoop_data(raw), "LATITUDE")
  expect_error(format_zoop_data(raw), "Columns present")
})

test_that("a combination stage is flagged rather than read as a total", {
  # CALANUS_FINMARCHICUS_CV_VI is neither CV nor a total, and read as a total it
  # still produces a plausible number - which is why it has to be said out loud.
  expect_warning(zoop_taxa("CALANUS_FINMARCHICUS_CV_VI_10M2"),
                 "contains a stage marker")
  expect_warning(zoop_taxa("CALANUS_FINMARCHICUS_CV_VI_10M2"), "CV_VI")

  # A plain stage on the end is read, not warned about.
  expect_silent(zoop_taxa("CALANUS_FINMARCHICUS_CV_10M2"))
})

test_that("a taxon name that prefixes another is flagged", {
  # column_prefix matches "<prefix>_", so CALANUS would collect
  # CALANUS_FINMARCHICUS's stage columns as if they were its own.
  expect_warning(zoop_taxa(c("CALANUS_10M2", "CALANUS_FINMARCHICUS_CV_10M2")),
                 "prefixes of others")
})

test_that("two columns resolving to one name is an error", {
  # A warning would leave one column silently overwriting the other.
  expect_error(zoop_taxa(c("TAXON_CV_10M2", "TAXON_CV_10M2")),
               "resolve to the same name")
})

test_that("the real export header raises nothing", {
  # A check that fires on ordinary data is worse than no check, so this is the
  # case that matters: the actual ECOMON taxon columns must pass in silence.
  header <- c("CALANUS_FINMARCHICUS_10M2", "CALANUS_HYPERBOREUS_10M2",
              "CALANUS_SPP_10M2", "CALANIDAE_10M2", "NANNOCALANUS_MINOR_10M2",
              "CENTROPAGES_TYPICUS_10M2", "CENTROPAGES_HAMATUS_10M2",
              "PSEUDOCALANUS_SPP_10M2", "TEMORA_LONGICORNIS_10M2",
              "METRIDIA_LUCENS_10M2", "OITHONA_SPP_10M2", "ONCAEA_SPP_10M2",
              "PARAEUCHAETA_NORVEGICA_10M2", "EUPHAUSIACEA_10M2",
              "CHAETOGNATHA_10M2", "APPENDICULARIA_10M2")

  expect_silent(taxa <- zoop_taxa(header))
  expect_equal(nrow(taxa), length(header))
  expect_true(all(is.na(taxa$stage)))
})
