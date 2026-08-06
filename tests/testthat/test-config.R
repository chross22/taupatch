test_that("load_config resolves paths and the active species", {
  config <- mock_config()

  expect_true(is_absolute_path(config$paths$output_dir))
  expect_equal(config$species$resolved$name, "cfin")
  expect_equal(config$species$resolved$column_prefix, "cfin")
  expect_equal(config$species$resolved$threshold$type, "percentile")
})

test_that("column_prefix defaults to the species key but can alias it", {
  config <- mock_config()

  # cfin/ctyp columns are named after the species, so no alias is needed.
  config$species$active <- "cfin"
  expect_equal(resolve_species(config)$column_prefix, "cfin")

  # pcal is the one species whose database columns use a different prefix.
  config$species$active <- "pcal"
  expect_equal(resolve_species(config)$column_prefix, "pseudo")

  # An entry with no column_prefix at all falls back to its key.
  config$species$catalog$newsp <- list(threshold = list(type = "percentile", value = 0.9))
  config$species$active <- "newsp"
  expect_equal(resolve_species(config)$column_prefix, "newsp")
})

test_that("defaults target ECOMON", {
  config <- apply_config_defaults(list())

  expect_equal(config$columns$dataset_filter, "ECOMON")
  expect_equal(config$columns$lat, "lat")
  # model.type is deliberately absent from the defaults so resolve_model_type()
  # can still read an older config's `engine`; a default would overwrite that
  # inference and make `engine: xgboost` silently fit a forest.
  expect_null(config$model$type)
  expect_equal(resolve_model_type(config), "rf")
  expect_false(config$model$tune)
})

test_that("an unknown active species is rejected", {
  config <- mock_config()
  config$species$active <- "not_a_species"

  expect_error(validate_species(config), "must be one of species.catalog")
})

test_that("a species cannot set both an abundance column and a column prefix", {
  config <- mock_config()
  config$species$catalog$ctyp$abundance_column <- "ctyp_total"

  expect_error(validate_species(config), "use one or the other")
})

test_that("stages require a column prefix rather than a total column", {
  config <- mock_config()
  config$species$catalog$ctyp$column_prefix <- NULL
  config$species$catalog$ctyp$abundance_column <- "ctyp_total"
  config$species$catalog$ctyp$stages <- "CV"

  expect_error(validate_species(config), "requires 'column_prefix'")
})

test_that("thresholds are validated by type, not by magnitude", {
  # The original inferred percentile-vs-absolute from `threshold < 1`, which
  # misreads any real abundance threshold below 1. Type is explicit now, so a
  # small absolute threshold is valid and a percentile outside (0,1) is not.
  expect_error(validate_threshold(list(type = "percentile", value = 1.5), "x"),
               "strictly between 0 and 1")
  expect_error(validate_threshold(list(type = "bogus", value = 0.5), "x"),
               "must be 'percentile' or 'absolute'")
  expect_error(validate_threshold(list(type = "percentile"), "x"), "both 'type' and 'value'")

  expect_true(validate_threshold(list(type = "absolute", value = 0.5), "x"))
  expect_true(validate_threshold(list(type = "percentile", value = 0.9), "x"))
})

test_that("validate_columns names every missing column", {
  config <- mock_config()
  generate_mock_zoop_data(config, n_stations = 20)

  expect_true(validate_columns(config))

  config$columns$lat <- "latitude"
  config$columns$lon <- "longitude"
  expect_error(validate_columns(config), "latitude")
  expect_error(validate_columns(config), "longitude")
})

test_that("the projection window defaults to the training window", {
  config <- mock_config()

  expect_equal(config$projection$years, config$dates$years)
  expect_equal(config$projection$months, config$dates$months)
})

test_that("the projection window can differ from the training window", {
  config <- mock_config()
  config$projection$years <- c(2020, 2021)
  config$projection$months <- c(1, 3)

  expect_true(validate_dates(config))
  expect_equal(config$dates$years, c(2018, 2019))
})

test_that("covariates are fetched for the union of both windows", {
  config <- mock_config()
  config$dates$years <- c(2018, 2019)
  config$dates$months <- c(6, 8)
  config$projection$years <- c(2021, 2021)
  config$projection$months <- c(1, 2)

  period <- covariate_period(config)

  # Both windows must be covered: training needs covariates to match to
  # stations, projection needs them to predict over.
  expect_true(all(c(2018, 2019, 2021) %in% period$years))
  expect_true(all(c(1, 2, 6, 7, 8) %in% period$months))
  # The gap between the windows is not fetched.
  expect_false(2020 %in% period$years)
  expect_false(4 %in% period$months)
})

test_that("an invalid projection window is reported as such", {
  config <- mock_config()
  config$projection$years <- c(2021, 2019)

  expect_error(validate_dates(config), "projection.years")
})

test_that("study area and covariate source are validated", {
  config <- mock_config()

  config$study_area$bbox$xmin <- config$study_area$bbox$xmax + 1
  expect_error(validate_study_area(config), "xmin < xmax")

  config <- mock_config()
  config$covariates$source <- "ftp"
  expect_error(validate_covariates(config), "must be one of")
})
