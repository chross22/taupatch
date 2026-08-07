test_that("uncertainty is off unless asked for, and true means defaults", {
  config <- mock_config()
  expect_null(uncertainty_settings(config))

  config$projection$uncertainty <- FALSE
  expect_null(uncertainty_settings(config))

  config$projection$uncertainty <- TRUE
  settings <- uncertainty_settings(config)
  expect_equal(settings$method, "folds")
  expect_equal(settings$level, 0.9)
  expect_true(settings$novelty)
})

test_that("a settings block overrides only what it names", {
  config <- mock_config()
  config$projection$uncertainty <- list(method = "bootstrap", replicates = 25)
  settings <- uncertainty_settings(config)

  expect_equal(settings$method, "bootstrap")
  expect_equal(settings$replicates, 25L)
  expect_equal(settings$level, 0.9)   # untouched
})

test_that("malformed uncertainty settings are refused at config load", {
  config <- mock_config()

  config$projection$uncertainty <- list(method = "jackknife")
  expect_error(uncertainty_settings(config), "must be 'folds' or 'bootstrap'")

  config$projection$uncertainty <- list(level = 95)
  expect_error(uncertainty_settings(config), "between 0 and 1")

  config$projection$uncertainty <- list(method = "bootstrap", replicates = 1)
  expect_error(uncertainty_settings(config), "at least 2")

  # Folds are the members, so too few folds means nothing to spread over.
  config$projection$uncertainty <- TRUE
  config$model$cv_folds <- 2
  expect_error(validate_uncertainty(config), "at least 3")
})

# ---- novelty ----------------------------------------------------------------

test_that("similarity is negative outside the training range and scaled by it", {
  train <- c(0, 10)   # range of 10

  # Half a range below the minimum, and one range above the maximum.
  expect_equal(unname(variable_similarity(-5, train)), -50)
  expect_equal(unname(variable_similarity(20, train)), -100)

  # Inside, it is positive. The endpoints are the edge of the range, not
  # outside it, so they are not negative.
  expect_gte(variable_similarity(5, train), 0)
})

test_that("similarity peaks at the middle of the training data", {
  train <- 1:101

  middle <- variable_similarity(51, train)
  edge <- variable_similarity(95, train)

  expect_gt(middle, edge)
  expect_lte(middle, 100)
})

test_that("a cell is as novel as its worst predictor, and says which", {
  train <- data.frame(SST = c(4, 8, 12, 16), CHL = c(0.2, 0.5, 1.0, 2.0))
  grid <- data.frame(SST = c(10, 25, 10), CHL = c(0.6, 0.6, 9.0))

  out <- novelty_surface(grid, train, c("SST", "CHL"))

  # Ordinary on both.
  expect_gt(out$novelty[1], 0)
  # One predictor outside its range is enough, however ordinary the other is.
  expect_lt(out$novelty[2], 0)
  expect_equal(out$novel_variable[2], "SST")
  expect_lt(out$novelty[3], 0)
  expect_equal(out$novel_variable[3], "CHL")
})

test_that("novelty survives a single-row grid and a constant predictor", {
  train <- data.frame(SST = c(4, 8, 12), FLAT = c(1, 1, 1))

  # vapply collapses a one-row result to a vector, which indexed wrongly before.
  one <- novelty_surface(data.frame(SST = 8, FLAT = 1), train, c("SST", "FLAT"))
  expect_equal(nrow(one), 1)
  expect_false(is.na(one$novelty))

  # A predictor that never varied can only say same-or-not.
  differs <- novelty_surface(data.frame(SST = 8, FLAT = 2), train, c("SST", "FLAT"))
  expect_true(differs$novelty < 0)
  expect_equal(differs$novel_variable, "FLAT")
})

test_that("novelty reports NA rather than guessing when a cell has none", {
  train <- data.frame(SST = c(4, 8, 12))
  out <- novelty_surface(data.frame(SST = NA_real_), train, "SST")

  expect_true(is.na(out$novelty))
})

test_that("the log line names the predictors driving extrapolation", {
  note <- novelty_message(c(5, -10, -3, 40), c("SST", "CHL", "CHL", "SST"))

  expect_match(note, "2 of 4")
  expect_match(note, "CHL")
  # Nothing to say when nothing is extrapolated, rather than a line saying zero.
  expect_null(novelty_message(c(5, 40), c("SST", "SST")))
})

# ---- ensemble ---------------------------------------------------------------

test_that("an ensemble too small to spread over yields no interval", {
  expect_null(ensemble_spread(list(), data.frame(x = 1)))
})

test_that("a run with uncertainty on adds layers without moving the map", {
  skip_if_not_installed("ranger")
  skip_if_not_installed("datamatch")

  config <- mock_config()
  generate_mock_zoop_data(config)
  plain <- suppressMessages(run_taupatch(config))

  config$projection$uncertainty <- TRUE
  config$paths$output_dir <- file.path(tempdir(), "uncertain_run")
  uncertain <- suppressMessages(run_taupatch(config))

  # The fold models come back from cross-validation rather than being refitted.
  expect_length(uncertain$model$ensemble, config$model$cv_folds)
  expect_length(plain$model$ensemble, 0)

  table <- readr::read_csv(
    file.path(config$paths$output_dir, "projections", "suitability.csv"),
    show_col_types = FALSE
  )
  expect_true(all(c("suitability_sd", "suitability_lower", "suitability_upper",
                    "novelty", "novel_variable") %in% names(table)))

  # An interval is an interval.
  expect_true(all(table$suitability_lower <= table$suitability_upper, na.rm = TRUE))
  expect_true(all(table$suitability_sd >= 0, na.rm = TRUE))
  # And everything on it is still a probability.
  expect_true(all(table$suitability_lower >= 0 & table$suitability_upper <= 1,
                  na.rm = TRUE))

  # The point estimate is the full-data model either way: turning uncertainty
  # on must not move the surface it is describing.
  expect_equal(nrow(table), sum(uncertain$projections$n_cells))
  expect_equal(plain$projections$n_cells, uncertain$projections$n_cells)
})

test_that("the extra surfaces reach the GeoTIFF as named layers", {
  skip_if_not_installed("ranger")
  skip_if_not_installed("datamatch")

  config <- mock_config()
  config$projection$uncertainty <- TRUE
  config$paths$output_dir <- file.path(tempdir(), "uncertain_tif")
  generate_mock_zoop_data(config)

  result <- suppressMessages(run_taupatch(config))
  layers <- terra::rast(result$projections$geotiff[1])

  # A GIS opening the tif gets the interval with the mean rather than having to
  # know a second file exists.
  expect_true(all(c("suitability", "suitability_sd", "suitability_lower",
                    "suitability_upper", "novelty") %in% names(layers)))

  # The uncertainty figure is written beside the suitability map, not over it.
  plots <- list.files(file.path(config$paths$output_dir, "plots"))
  expect_true(any(grepl("_uncertainty\\.png$", plots)))
  expect_true(any(!grepl("_uncertainty\\.png$", plots)))
})
