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
