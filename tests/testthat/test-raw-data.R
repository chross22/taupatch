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
  on.exit(Sys.setlocale("LC_TIME", old), add = TRUE)

  # Whether the locale actually changed, rather than what setlocale returned.
  # A missing locale gives NA on some platforms and "" on others - a bare
  # Ubuntu runner has no French locale and returns the empty string - so
  # checking the return value let this run anywhere and fail on the CI boxes
  # that had nothing to switch to.
  suppressWarnings(Sys.setlocale("LC_TIME", "fr_FR.UTF-8"))
  french <- Sys.getlocale("LC_TIME")
  if (!grepl("^fr_FR", french)) {
    skip("no French locale installed to test against")
  }

  out <- split_dates(data.frame(DATE = c("05-JAN-03", "17-JUN-11")))

  expect_equal(out$year, c(2003L, 2011L))
  expect_equal(out$month, c(1L, 6L))
  # Parsing switches to C and puts back what it found, rather than leaving the
  # session in whatever locale it needed.
  expect_equal(Sys.getlocale("LC_TIME"), french)
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
  # Divided by ten, since the export counts per 10 m2.
  expect_equal(out$CALANUS_FINMARCHICUS, c(120, 34))
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
  config$species$catalog <- species_catalog_from(names(raw_export()))
  config$species$active <- "cfin"
  config$species$resolved <- resolve_species(config)

  # The whole point: a formatted export is a database load_zoop_data() reads.
  expect_true(validate_columns(config))
  dat <- load_zoop_data(config)
  expect_equal(nrow(dat), 2)
  # Divided by ten on the way in: the export counts per 10 m2.
  expect_equal(sort(dat$abundance), c(34, 120))
})

test_that("the catalog form follows whether the dataset resolves stages", {
  unstaged <- species_catalog_from(names(raw_export()))
  # Keyed by shorthand, pointing at the column header name.
  expect_equal(unstaged$cfin$abundance_column, "CALANUS_FINMARCHICUS")
  expect_null(unstaged$cfin$column_prefix)

  staged <- species_catalog_from(names(raw_export(staged = TRUE)))
  expect_equal(staged$pcal$column_prefix, "PSEUDOCALANUS_SPP")
  expect_null(staged$pcal$abundance_column)
  # The unstaged taxa in the same file keep their own form.
  expect_equal(staged$ctyp$abundance_column, "CENTROPAGES_TYPICUS")
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
  config$species$active <- "pcal"
  config$species$catalog$pcal$stages <- "CV"
  config$species$resolved <- resolve_species(config)
  config$dates$years <- c(2003, 2011); config$dates$months <- c(1, 12)
  config$study_area$bbox <- list(xmin = -71, xmax = -69, ymin = 42, ymax = 44)

  dat <- load_zoop_data(config)
  # Only the requested stage, not the sum of both, and per m2 rather than
  # per 10 m2.
  expect_setequal(dat$abundance, c(3, 2.5))
})

test_that("aliases must name taxa the file has", {
  expect_error(
    species_catalog_from(names(raw_export()), aliases = c(cf = "CALANUS_NOPE")),
    "not in the data"
  )
})

test_that("shorthand is the genus initial and three letters of the epithet", {
  expect_equal(taxon_shorthand("CALANUS_FINMARCHICUS"), "cfin")
  expect_equal(taxon_shorthand("CENTROPAGES_TYPICUS"), "ctyp")
  # Case in the header is not part of the identity.
  expect_equal(taxon_shorthand("calanus_finmarchicus"), "cfin")
  # A single-word name has no epithet to take three letters from.
  expect_equal(taxon_shorthand("CALANIDAE"), "cala")
})

test_that("a shorthand collision falls back to three letters of the genus", {
  # Real, in the ECOMON header: OITHONA_SPP and ONCAEA_SPP both give `ospp`.
  expect_silent(short <- taxon_shorthand(c("OITHONA_SPP", "ONCAEA_SPP")))
  expect_equal(short, c("oitspp", "oncspp"))

  # Taxa that do not collide are untouched by the rule.
  expect_equal(taxon_shorthand(c("OITHONA_SPP", "CALANUS_FINMARCHICUS")),
               c("ospp", "cfin"))
})

test_that("single-word names lengthen until they separate", {
  # Real, in the ECOMON header: both give `pseu` on four letters.
  expect_silent(short <- taxon_shorthand(c("PSEUDOCALANIDAE", "PSEUDODIAPTOMIDAE")))
  expect_equal(length(unique(short)), 2)
  expect_true(all(startsWith(short, "pseudo")))

  # Whereas differing epithets never collided in the first place.
  expect_silent(taxon_shorthand(c("OITHONA_SPP", "OITHONA_SIMILIS")))
})

test_that("Pseudocalanus keeps its conventional shorthand", {
  expect_equal(taxon_shorthand("PSEUDOCALANUS_SPP"), "pcal")
  expect_equal(taxon_shorthand("pseudocalanus_newmani"), "pcal")
})

test_that("a raw export is told from a station database by its header", {
  expect_true(is_raw_export(c("STATION", "LATITUDE", "LONGITUDE", "DATE")))
  expect_false(is_raw_export(c("station", "lat", "lon", "year", "month", "day")))
})

test_that("abundance is divided by the count its unit is per", {
  # _10M2 is animals per ten square metres, so per one is a tenth of it.
  expect_equal(abundance_units("_10M2"), list(per = 10, unit = "M2"))
  expect_equal(abundance_units("_100M3"), list(per = 100, unit = "M3"))
  # A unit with no number is already per one.
  expect_equal(abundance_units("_M2"), list(per = 1, unit = "M2"))

  out <- format_zoop_data(raw_export())
  expect_equal(out$CALANUS_FINMARCHICUS, c(120, 34))
  expect_equal(attr(out, "abundance_unit"), "M2")
})

test_that("a file mixing two abundance units is reported", {
  # Per m2 is an areal density and per m3 a concentration; only columns in the
  # chosen unit are read, and the rest would pass silently as measurements.
  expect_warning(zoop_taxa(c("CALANUS_FINMARCHICUS_10M2", "METRIDIA_LUCENS_100M3")),
                 "other units")
})

test_that("the original date column is kept", {
  out <- format_zoop_data(raw_export())

  # year/month/day are derived from it, and dropping the source would make the
  # derivation unverifiable.
  expect_true("DATE" %in% names(out))
  expect_equal(out$year, c(2003L, 2011L))
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

test_that("a combination stage belongs to its taxon", {
  # This used to be read as an animal called CALANUS_FINMARCHICUS_CV_VI, which
  # split one species across several entries in the picker.
  taxa <- zoop_taxa("CALANUS_FINMARCHICUS_CV_VI_10M2")

  expect_equal(taxa$taxon, "CALANUS_FINMARCHICUS")
  expect_equal(taxa$stage, "CV_VI")
  expect_silent(zoop_taxa("CALANUS_FINMARCHICUS_CV_10M2"))
})

test_that("a stage marker stranded mid-name is still flagged", {
  # Recoverable only when the stage is on the end. Anything else cannot be told
  # from part of the taxon's own name, so it is reported rather than guessed.
  expect_warning(zoop_taxa("CALANUS_CV_FINMARCHICUS_10M2"),
                 "contains a stage marker")
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

  # OITHONA_SPP and ONCAEA_SPP both shorten to `ospp`, which is worth a warning
  # and is not what this test is about.
  header <- setdiff(header, "ONCAEA_SPP_10M2")

  expect_silent(taxa <- zoop_taxa(header))
  expect_equal(nrow(taxa), length(header))
  expect_true(all(is.na(taxa$stage)))
})

test_that("stage suffixes are recognized whatever case they are written in", {
  # The raw export is upper case throughout; create_database.R writes a lower
  # case taxon with an upper case stage. Both are the same animal.
  expect_equal(zoop_taxa("cfin_CI_10M2")$taxon, "cfin")
  expect_equal(zoop_taxa("cfin_ci_10M2")$taxon, "cfin")
  expect_equal(zoop_taxa("CFIN_CI_10M2")$taxon, "CFIN")

  # The stage code is normalized upward so it lines up with single_stages()
  # regardless of how the database wrote it.
  expect_equal(zoop_taxa("cfin_ci_10M2")$stage, "CI")
})

test_that("every stage form the databases use groups under its taxon", {
  # The bug this fixes: each of these read as an animal of its own, so one
  # species appeared in the picker seven times under seven names.
  header <- c("cfin_CI", "cfin_CV", "cfin_CV_VI", "cfin_total",
              "ctyp_adult", "ctyp_C", "pseudo_CI_IV")

  found <- available_species(header)

  expect_setequal(found$species, c("cfin", "ctyp", "pseudo"))
  expect_true(all(found$form == "stages"))
  # A total is that taxon's total rather than one of its stages, so it groups
  # the columns without being offered as something to select.
  expect_false(grepl("TOTAL", found$stages[found$species == "cfin"]))
  expect_true(grepl("CV_VI", found$stages[found$species == "cfin"]))
  expect_true(grepl("ADULT", found$stages[found$species == "ctyp"]))
})

test_that("a total and a stage of one taxon do not collide", {
  taxa <- zoop_taxa(c("cfin_10M2", "cfin_total_10M2", "cfin_CV_10M2"))

  expect_true(all(taxa$taxon == "cfin"))
  # Three source columns, three distinct destinations.
  expect_equal(length(unique(taxa$name)), 3)
  expect_setequal(taxa$name, c("cfin", "cfin_total", "cfin_CV"))
})

test_that("real taxon names are not mistaken for stages", {
  # The check that matters: a broader stage rule must not start eating the ends
  # of ordinary species names.
  header <- c("CALANUS_FINMARCHICUS", "CALANUS_SPP", "CENTROPAGES_TYPICUS",
              "CLAUSOCALANUS_ARCUICORNIS", "PARAEUCHAETA_NORVEGICA",
              "METRIDIA_LUCENS", "TEMORA_LONGICORNIS", "OITHONA_SPP",
              "CHAETOGNATHA", "APPENDICULARIA")

  found <- available_species(header)

  expect_setequal(found$species, header)
  expect_true(all(found$form == "total"))
})

test_that("one taxon spelled two ways is flagged", {
  expect_warning(zoop_taxa(c("cfin_CI_10M2", "CFIN_CV_10M2")),
                 "spelled more than one way")
})
