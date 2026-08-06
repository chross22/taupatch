test_that("the full pipeline runs end-to-end on mock data", {
  skip_if_not_installed("ranger")
  skip_if_not_installed("datamatch")

  config <- mock_config()
  generate_mock_zoop_data(config)

  result <- suppressMessages(run_taupatch(config))

  # The mock data plants a latitudinal gradient and a seasonal cycle into both
  # abundance and the covariates, so a working pipeline must score well clear of
  # chance. A smoke test that passed on noise would not be testing anything.
  roc_auc <- result$model$metrics$mean[result$model$metrics$.metric == "roc_auc"]
  expect_gt(roc_auc, 0.7)

  expect_s3_class(result$model$workflow, "workflow")
  # Predictors carry the covariate names the config asked for, not Copernicus
  # variable codes like thetao/so.
  expect_true(all(c("SST", "SSS", "jday") %in% result$model$predictors))
  expect_true("tss" %in% result$model$metrics$.metric)

  # One projection per configured month x year.
  n_expected <- length(seq(config$projection$years[1], config$projection$years[2])) *
    length(seq(config$projection$months[1], config$projection$months[2]))
  expect_equal(nrow(result$projections), n_expected)

  out <- config$paths$output_dir
  expect_true(file.exists(file.path(out, "model.rds")))
  expect_true(file.exists(file.path(out, "evals.csv")))
  expect_true(file.exists(file.path(out, "var_importance.csv")))
  expect_true(file.exists(file.path(out, "threshold.yaml")))
  expect_true(all(file.exists(result$projections$geotiff)))
  expect_true(all(file.exists(result$projections$png)))
})

test_that("projected suitability stays a probability", {
  skip_if_not_installed("ranger")
  skip_if_not_installed("datamatch")

  config <- mock_config()
  generate_mock_zoop_data(config)
  result <- suppressMessages(run_taupatch(config))

  rast <- terra::rast(result$projections$geotiff[1])
  values <- terra::values(rast, na.rm = TRUE)

  expect_true(all(values >= 0 & values <= 1))
})

test_that("projection covers its own window, not the training window", {
  skip_if_not_installed("ranger")
  skip_if_not_installed("datamatch")

  config <- mock_config()
  # Train on 2018-2019 June-August, project only July 2019.
  config$projection$years <- c(2019, 2019)
  config$projection$months <- c(7, 7)
  generate_mock_zoop_data(config)

  result <- suppressMessages(run_taupatch(config))

  expect_equal(nrow(result$projections), 1)
  expect_equal(result$projections$year, 2019)
  expect_equal(result$projections$month, 7)
  # The model still saw the full training window.
  expect_true(all(c(2018, 2019) %in% unique(result$data$year)))
})

test_that("run_taupatch can skip projection", {
  skip_if_not_installed("ranger")
  skip_if_not_installed("datamatch")

  config <- mock_config()
  generate_mock_zoop_data(config)

  result <- suppressMessages(run_taupatch(config, project = FALSE))

  expect_null(result$projections)
  expect_s3_class(result$model$workflow, "workflow")
})

test_that("projection_map sets a view with plain numeric bounds", {
  skip_if_not_installed("leaflet")
  skip_if_not_installed("ranger")
  skip_if_not_installed("datamatch")

  config <- mock_config()
  generate_mock_zoop_data(config)
  result <- suppressMessages(run_taupatch(config))

  map <- projection_map(result$projections$geotiff[1])
  methods <- vapply(map$x$calls, function(call) call$method, character(1))

  expect_true("addRasterImage" %in% methods)
  # A view must be set. Without one leaflet has no center or zoom, so it requests
  # no tiles and positions no overlay - the map renders as a blank grey box.
  expect_false(is.null(map$x$fitBounds))

  # terra's SpatExtent indexing returns *named* numerics, and jsonlite renders a
  # named vector as a JSON object rather than a scalar, so fitBounds would
  # receive {"xmin": -70.1} instead of -70.1 and silently set no view. Each
  # bound must be an unnamed length-1 number.
  bounds <- map$x$fitBounds[1:4]
  for (bound in bounds) {
    expect_true(is.numeric(bound))
    expect_length(bound, 1)
    expect_null(names(bound))
  }

  # And the bounds must be the raster's own extent, in leaflet's
  # (lat1, lng1, lat2, lng2) order.
  extent <- unname(as.vector(terra::ext(terra::rast(result$projections$geotiff[1]))))
  expect_equal(unlist(bounds), c(extent[3], extent[1], extent[4], extent[2]))
})

test_that("the progress stages are ordered and cover the run", {
  stages <- pipeline_stages()

  expect_true(all(diff(stages$at) > 0))
  expect_true(all(stages$at > 0 & stages$at < 1))
  expect_true(all(nzchar(stages$label)))
  # Weighted rather than even: the covariate download is most of a real run, so
  # the bar should sit in it rather than sprint past.
  download <- stages$at[stages$label == "Downloading covariates from Copernicus"]
  next_stage <- min(stages$at[stages$at > download])
  expect_gt(next_stage - download, 0.3)
})

test_that("every stage a run announces moves the bar", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 3
  config$projection$years <- c(2018, 2018)
  config$projection$months <- c(6, 6)
  config$projection$write_geotiff <- FALSE
  config$projection$write_png <- FALSE
  generate_mock_zoop_data(config)

  seen <- character()
  withCallingHandlers(
    invisible(suppressWarnings(run_taupatch(config))),
    message = function(m) {
      seen <<- c(seen, sub("\n$", "", conditionMessage(m)))
      invokeRestart("muffleMessage")
    }
  )

  # A top-level message is a stage starting. One the table does not know about
  # is a stage the bar sits still through, which is how a progress bar comes to
  # look frozen.
  top_level <- seen[!grepl("^\\s", seen)]
  unmatched <- Filter(function(t) is.null(match_pipeline_stage(t)), top_level)
  expect_length(unmatched, 0)

  # And the run reaches the end of the bar rather than stopping partway.
  reached <- vapply(top_level, function(t) match_pipeline_stage(t)$at, numeric(1))
  expect_gte(max(reached), 0.99)
})

test_that("detail lines do not move the bar", {
  # Indented messages are progress within a stage - a record count, a threshold -
  # and moving the bar for each would race it through the quick stages.
  expect_null(match_pipeline_stage("  684 station records"))
  expect_null(match_pipeline_stage("  ROC AUC: 0.8734"))
  expect_null(match_pipeline_stage("  threshold: 9315.31"))
})

test_that("a run writes the probabilities as a long table", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 3
  config$projection$years <- c(2018, 2019)
  config$projection$months <- c(6, 7)
  config$projection$write_png <- FALSE
  generate_mock_zoop_data(config)

  result <- suppressMessages(suppressWarnings(run_taupatch(config)))
  table <- attr(result$projections, "table")

  expect_true(!is.null(table) && file.exists(table))
  rows <- readr::read_csv(table, show_col_types = FALSE, progress = FALSE)

  # Coordinates and time on every row, which is the point: a GeoTIFF carries
  # its coordinates and says nothing about which month it is.
  expect_setequal(names(rows),
                  c("species", "year", "month", "lon", "lat", "suitability"))
  expect_setequal(unique(paste(rows$year, rows$month)),
                  c("2018 6", "2018 7", "2019 6", "2019 7"))
  expect_true(all(rows$suitability >= 0 & rows$suitability <= 1))
  # Long, not wide: one row per cell per month.
  expect_equal(nrow(rows), sum(result$projections$n_cells))
})

test_that("the probability table can be turned off", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 3
  config$projection$years <- c(2018, 2018)
  config$projection$months <- c(6, 6)
  config$projection$write_png <- FALSE
  config$projection$write_csv <- FALSE
  generate_mock_zoop_data(config)

  result <- suppressMessages(suppressWarnings(run_taupatch(config)))

  expect_null(attr(result$projections, "table"))
  expect_false(file.exists(file.path(config$paths$output_dir, "projections",
                                     "suitability.csv")))
})

test_that("the monthly projections stack into one raster", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 3
  config$projection$years <- c(2018, 2019)
  config$projection$months <- c(6, 7)
  config$projection$write_png <- FALSE
  config$projection$write_grd <- TRUE
  generate_mock_zoop_data(config)

  result <- suppressMessages(suppressWarnings(run_taupatch(config)))
  path <- attr(result$projections, "stack")

  expect_true(!is.null(path) && file.exists(path))
  # Two files, and one is no use without the other.
  expect_true(file.exists(sub("[.]grd$", ".gri", path)))

  stack <- terra::rast(path)
  expect_equal(terra::nlyr(stack), nrow(result$projections))
  # The dates are the reason for stacking, so they have to survive the write.
  expect_equal(names(stack), c("2018_06", "2018_07", "2019_06", "2019_07"))
  expect_equal(format(terra::time(stack)),
               c("2018-06-15", "2018-07-15", "2019-06-15", "2019-07-15"))

  # Same numbers as the GeoTIFF they came from.
  first <- terra::rast(result$projections$geotiff[1])
  expect_equal(as.vector(terra::values(stack[[1]])),
               as.vector(terra::values(first)))

  # The values are probabilities. Checked against the data rather than the
  # header: terra writes a .grd header with no range in it, so minmax() reports
  # a placeholder near 1e38 for any raster written this way, correct or not.
  values <- terra::values(stack)
  expect_true(all(values >= 0 & values <= 1, na.rm = TRUE))
  expect_gt(max(values, na.rm = TRUE), 0)
})

test_that("the stack can be built after the fact, and says so when it cannot", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 3
  config$projection$years <- c(2018, 2018)
  config$projection$months <- c(6, 6)
  config$projection$write_png <- FALSE
  generate_mock_zoop_data(config)

  result <- suppressMessages(suppressWarnings(run_taupatch(config)))
  expect_null(attr(result$projections, "stack"))

  path <- file.path(tempfile("stack"), "suitability.grd")
  dir.create(dirname(path))
  expect_equal(write_suitability_stack(result$projections, path), path)
  expect_equal(terra::nlyr(terra::rast(path)), 1L)

  # Nothing to stack when the run wrote no rasters.
  no_rasters <- result$projections
  no_rasters$geotiff <- NA_character_
  expect_error(write_suitability_stack(no_rasters, path), "No GeoTIFFs")
})
