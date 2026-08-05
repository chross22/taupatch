test_that("every catalog entry is fully specified", {
  catalog <- copernicus_covariates()

  expect_gt(length(catalog), 0)
  for (name in names(catalog)) {
    entry <- catalog[[name]]
    for (field in c("label", "units", "variable", "product_id", "dataset_id",
                     "description")) {
      expect_true(nzchar(entry[[field]] %||% ""),
                  info = paste(name, "is missing", field))
    }
  }
})

test_that("covariate_info tabulates the catalog plus derived covariates", {
  info <- covariate_info(include_derived = FALSE)
  # Every fetchable covariate: Copernicus time-varying ones plus the static
  # seafloor ones from NOAA ETOPO.
  expect_setequal(info$name,
                  c(names(copernicus_covariates()), names(bathymetry_covariates())))
  expect_false("jday" %in% info$name)

  # jday is a predictor too, so the reference table should explain it even
  # though it is computed rather than fetched.
  expect_true("jday" %in% covariate_info(include_derived = TRUE)$name)
})

test_that("covariates sharing a dataset are fetched in one request", {
  # SST, SSS and MLD all come from the physics dataset; CHL comes from the
  # biogeochemistry one. Three separate requests for the physics variables would
  # be three times the download for the same data.
  specs <- resolve_covariate_specs(c("SST", "SSS", "MLD", "CHL"))

  expect_length(specs, 2)
  physics <- Filter(function(s) "thetao" %in% s$vars, specs)[[1]]
  expect_setequal(physics$vars, c("thetao", "so", "mlotst"))
  expect_setequal(physics$names, c("SST", "SSS", "MLD"))
})

test_that("specs record the mapping back to covariate names", {
  specs <- resolve_covariate_specs(c("SST", "SSS"))

  # The order of `names` must line up with `vars`, since fetched columns are
  # renamed positionally.
  expect_equal(specs[[1]]$vars, c("thetao", "so"))
  expect_equal(specs[[1]]$names, c("SST", "SSS"))
})

test_that("an unknown covariate lists the available ones", {
  expect_error(resolve_covariate_specs(c("SST", "SALINITY")), "SALINITY")
  expect_error(resolve_covariate_specs(c("SST", "SALINITY")), "Available")
})

test_that("config validation rejects unknown and unselected covariates", {
  config <- mock_config()

  config$covariates$selected <- c("SST", "NOPE")
  expect_error(validate_covariates(config), "Unknown covariate")

  config$covariates$selected <- c("SST")
  config$covariates$log_transform <- "CHL"
  expect_error(validate_covariates(config), "not selected")
})

test_that("mock covariates are generated under the selected names", {
  config <- mock_config()
  config$covariates$selected <- c("SST", "CHL", "MLD")

  env <- generate_mock_covariates(config, years = 2018, months = 6)

  expect_true(all(c("SST", "CHL", "MLD") %in% names(env)))
  # Values should sit in each covariate's real range, not be generic noise.
  expect_true(all(env$CHL >= 0))
  expect_true(all(env$MLD > 0))
  expect_true(all(env$SST > -5 & env$SST < 40))
})

test_that("covariate_monthly_means collapses the grid to one value per month/year", {
  config <- mock_config()
  config$covariates$selected <- c("SST", "CHL")
  env <- generate_mock_covariates(config, years = c(2018, 2019), months = 6:8)

  means <- covariate_monthly_means(env)

  expect_setequal(names(means), c("year", "month", "covariate", "mean"))
  # 2 years x 3 months x 2 covariates
  expect_equal(nrow(means), 12)
  expect_setequal(unique(means$covariate), c("SST", "CHL"))
  expect_false(any(is.na(means$mean)))

  # The mean must match a direct calculation for one cell.
  flat <- sf::st_drop_geometry(env)
  expected <- mean(flat$SST[flat$YEAR == 2018 & flat$MONTH == 7])
  actual <- means$mean[means$covariate == "SST" & means$year == 2018 & means$month == 7]
  expect_equal(actual, expected)
})

test_that("the covariate heatmap recovers the planted seasonal cycle", {
  config <- mock_config()
  config$covariates$selected <- "SST"
  env <- generate_mock_covariates(config, years = 2018, months = 1:12)
  means <- covariate_monthly_means(env)

  # Mock SST peaks in late summer; if the month/year axes were transposed this
  # would not hold.
  peak_month <- means$month[which.max(means$mean)]
  expect_true(peak_month %in% 6:9)

  expect_s3_class(plot_covariate_heatmap(means, "SST"), "ggplot")
  expect_error(plot_covariate_heatmap(means, "NOPE"), "No values for covariate")
})
