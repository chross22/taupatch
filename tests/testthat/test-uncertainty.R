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

test_that("the MESS scale still reads the way the documentation says", {
  # The arithmetic belongs to fancyfx::mess() now, and is tested there. What is
  # checked here is the property this package documents and its readers rely
  # on: 100 at the median, falling to 0 at the edge of the training range, and
  # negative outside it in proportion to how far.
  train <- data.frame(x = 0:100)

  middle <- novelty_surface(data.frame(x = 50), train, "x")$novelty
  edge <- novelty_surface(data.frame(x = 99), train, "x")$novelty
  outside <- novelty_surface(data.frame(x = c(-50, 150)), train, "x")$novelty

  expect_lte(middle, 100)
  expect_gt(middle, edge)
  expect_gte(edge, 0)
  # Half a training range below the minimum, and half a range above the max.
  expect_equal(outside, c(-50, -50))
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

# ---- spatial sorting bias ---------------------------------------------------

test_that("spatially fair folds score near 1 and sorted ones score near 0", {
  # Built rather than fitted, so the answer is known in advance. Patches and
  # non-patches drawn from the same places is the fair case; patches clustered
  # away from the non-patches is the sorted one.
  set.seed(1)
  n <- 200
  fair <- data.frame(lon = runif(n, -70, -66), lat = runif(n, 41, 44))
  # Shuffled rather than alternating: `rep` of a 2-cycle across a 4-fold cycle
  # puts every patch in the odd folds, leaving each fold with one class and
  # nothing to compare.
  labels <- sample(rep(c("patch", "non_patch"), length.out = n))
  predictions <- data.frame(
    .row = seq_len(n),
    id = rep(paste0("Fold", 1:4), length.out = n),
    patch = factor(labels, levels = c("patch", "non_patch"))
  )

  unbiased <- spatial_bias(list(coordinates = fair, predictions = predictions))
  expect_equal(overall_ssb(unbiased), 1, tolerance = 0.35)

  # Now put every patch in one corner and every non-patch in another.
  sorted <- fair
  is_patch <- predictions$patch == "patch"
  sorted$lon[is_patch] <- runif(sum(is_patch), -70, -69.5)
  sorted$lon[!is_patch] <- runif(sum(!is_patch), -66.5, -66)

  biased <- spatial_bias(list(coordinates = sorted, predictions = predictions))
  expect_lt(overall_ssb(biased), overall_ssb(unbiased))
  expect_lt(overall_ssb(biased), 0.3)
})

test_that("spatial bias reports every fold as well as the overall", {
  set.seed(2)
  n <- 120
  coordinates <- data.frame(lon = runif(n, -70, -66), lat = runif(n, 41, 44))
  predictions <- data.frame(
    .row = seq_len(n),
    id = rep(paste0("Fold", 1:3), length.out = n),
    patch = factor(sample(rep(c("patch", "non_patch"), length.out = n)),
                   levels = c("patch", "non_patch"))
  )

  out <- spatial_bias(list(coordinates = coordinates, predictions = predictions))

  expect_equal(nrow(out), 4)
  expect_equal(out$fold, c("Fold1", "Fold2", "Fold3", "overall"))
  expect_true(all(out$ssb > 0))
})

test_that("spatial bias declines to answer without coordinates", {
  # A model fitted on a hand-built frame has none, and that is not an error.
  predictions <- data.frame(.row = 1:4, id = "Fold1",
                            patch = factor(c("patch", "non_patch"),
                                           levels = c("patch", "non_patch")))

  expect_null(spatial_bias(list(coordinates = NULL, predictions = predictions)))
  expect_null(spatial_bias(list(coordinates = data.frame(lon = 1, lat = 1),
                                predictions = NULL)))
  expect_true(is.na(overall_ssb(NULL)))
})

test_that("the spatial bias note says what a low value means for the AUC", {
  expect_match(spatial_bias_note(0.95), "spatially fair")
  expect_match(spatial_bias_note(0.2), "optimistic")
  expect_match(spatial_bias_note(NA_real_), "could not be computed")
})

test_that("the fitted model carries its coordinates and its spatial bias", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 5
  dat <- labeled_mock_data(config)

  model <- fit_patch_model(dat, config)

  expect_equal(nrow(model$coordinates), nrow(model$model_data))
  expect_setequal(names(model$coordinates), c("lon", "lat"))
  expect_false(is.null(model$spatial_bias))
  # And it reaches the evaluation table, beside the metrics it qualifies.
  expect_true("ssb" %in% model$evaluation$metric)
})
