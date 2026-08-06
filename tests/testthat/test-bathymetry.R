# The conversion logic (elevation to positive depth, land masking, terrain
# derivation) now lives in datamatch and is tested there. What matters here is
# that taupatch delegates correctly and hands over the right study area.

test_that("bathymetry covariates come from datamatch", {
  # The delegation is the whole contract. Asserting a fixed list of names here
  # would restate datamatch's catalog as a second copy that breaks every time a
  # variable is added there - which is exactly what this package is trying not
  # to do.
  expect_identical(bathymetry_covariates(), datamatch::bathymetry_variables())
  expect_true(all(c("DEPTH", "SLOPE") %in% names(bathymetry_covariates())))
})

test_that("study_area_bathymetry passes the configured area and cache path", {
  config <- mock_config()
  captured <- NULL

  # Intercept the delegate rather than hitting NOAA.
  local_mocked_bindings(
    fetch_bathymetry = function(bounding_box, resolution, path, keep = TRUE) {
      captured <<- list(bounding_box = bounding_box, resolution = resolution,
                        path = path)
      "raster"
    },
    .package = "datamatch"
  )

  result <- study_area_bathymetry(config, resolution = 2)

  expect_equal(result, "raster")
  expect_equal(captured$bounding_box$xmin, config$study_area$bbox$xmin)
  expect_equal(captured$bounding_box$ymax, config$study_area$bbox$ymax)
  expect_equal(captured$resolution, 2)
  # Downloads belong with the rest of the run's outputs, not wherever R started.
  expect_true(grepl(config$paths$output_dir, captured$path, fixed = TRUE))
})

test_that("bathymetry covariates appear in the reference table", {
  info <- covariate_info()

  expect_true(all(c("DEPTH", "SLOPE", "ASPECT") %in% info$name))
  expect_equal(info$units[info$name == "DEPTH"], "m")
  expect_true(grepl("marmap", info$dataset[info$name == "DEPTH"]))
})

test_that("config validation separates seafloor covariates from Copernicus ones", {
  config <- mock_config()

  # DEPTH is static, so it belongs under covariates.bathymetry - and the error
  # should say so rather than just calling it unknown.
  config$covariates$selected <- c("SST", "DEPTH")
  expect_error(validate_covariates(config), "covariates.bathymetry")

  config$covariates$selected <- "SST"
  config$covariates$bathymetry <- "NOPE"
  expect_error(validate_covariates(config), "Unknown covariate")

  config$covariates$bathymetry <- c("DEPTH", "SLOPE")
  expect_true(validate_covariates(config))
})

test_that("a seafloor covariate can be log-transformed", {
  config <- mock_config()
  config$covariates$bathymetry <- "DEPTH"
  config$covariates$log_transform <- "DEPTH"

  expect_true(validate_covariates(config))
})
