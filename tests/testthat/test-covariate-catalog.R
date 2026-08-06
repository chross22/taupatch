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

# Two products on different grids, with month-distinguishable values, so a join
# that ignored time or resolution shows up as a wrong number rather than a
# subtly different one.
two_resolution_sources <- function() {
  fine <- do.call(rbind, lapply(1:2, function(m) {
    g <- expand.grid(x = seq(-70, -69, by = 0.25), y = seq(42, 43, by = 0.25))
    g$SST <- 10 + m; g$YEAR <- 2020; g$MONTH <- m; g$DAY <- 1L; g
  }))
  coarse <- do.call(rbind, lapply(1:2, function(m) {
    g <- expand.grid(x = seq(-70, -69, by = 0.5), y = seq(42, 43, by = 0.5))
    g$CHL <- 100 * m; g$YEAR <- 2020; g$MONTH <- m; g$DAY <- 1L; g
  }))
  list(
    fine = sf::st_as_sf(fine, coords = c("x", "y"), crs = 4326),
    coarse = sf::st_as_sf(coarse, coords = c("x", "y"), crs = 4326)
  )
}

test_that("joining two sources keeps each time step's own values", {
  # A single spatial join across the whole stack matches on geometry alone.
  # Every time step repeats the same coordinates, so st_nearest_feature
  # resolves the tie to one arbitrary step - attaching January's chlorophyll to
  # every month, silently and plausibly.
  sources <- two_resolution_sources()

  joined <- join_covariate_sources(sources$coarse, sources$fine)

  expect_equal(unique(joined$SST[joined$MONTH == 1]), 11)
  expect_equal(unique(joined$SST[joined$MONTH == 2]), 12)
})

test_that("grid_spacing measures a source's resolution", {
  sources <- two_resolution_sources()

  expect_equal(grid_spacing(sources$fine), 0.25)
  expect_equal(grid_spacing(sources$coarse), 0.5)
})

test_that("a source missing a time step yields NA rather than dropping rows", {
  sources <- two_resolution_sources()
  january_only <- sources$fine[sources$fine$MONTH == 1, ]

  joined <- join_covariate_sources(sources$coarse, january_only)

  # The row count must not depend on which products were selected.
  expect_equal(nrow(joined), nrow(sources$coarse))
  expect_false(any(is.na(joined$SST[joined$MONTH == 1])))
  expect_true(all(is.na(joined$SST[joined$MONTH == 2])))
})

test_that("the finest grid is kept by default, with coarse values repeated", {
  sources <- two_resolution_sources()
  config <- mock_config()

  spacing <- vapply(sources, grid_spacing, numeric(1))
  ordering <- order(spacing, decreasing = FALSE)
  joined <- Reduce(join_covariate_sources, sources[ordering])

  # The fine grid has 25 cells per step, the coarse one 9. Keeping the fine
  # grid means every fine cell survives.
  expect_equal(nrow(joined), nrow(sources$fine))
  # Chlorophyll is repeated rather than interpolated: still only its original
  # two distinct values, one per month.
  expect_setequal(unique(joined$CHL), c(100, 200))
})

test_that("choosing the coarsest grid replicates nothing", {
  sources <- two_resolution_sources()

  ordering <- order(vapply(sources, grid_spacing, numeric(1)), decreasing = TRUE)
  joined <- Reduce(join_covariate_sources, sources[ordering])

  expect_equal(nrow(joined), nrow(sources$coarse))
})

test_that("resolutions are read off the Copernicus dataset id", {
  # The id encodes both, so they are derived rather than maintained as a second
  # list that could drift from it.
  physics <- dataset_resolution("cmems_mod_glo_phy_my_0.083deg_P1M-m")
  expect_equal(physics$spatial, "0.083° (~9 km)")
  expect_equal(physics$temporal, "monthly")

  bgc <- dataset_resolution("cmems_mod_glo_bgc_my_0.25deg_P1M-m")
  expect_equal(bgc$spatial, "0.25° (~28 km)")

  # Satellite products state kilometres rather than degrees. Both forms have to
  # parse, because which of two products is finer decides which grid a run
  # lands on - and 4 km ocean-colour chlorophyll is finer than the 0.083 degree
  # physics it joins to, which reading only degrees would get backwards.
  satellite <- dataset_resolution("cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M")
  expect_equal(satellite$spatial, "4 km (~0.036°)")
  expect_equal(satellite$temporal, "monthly")

  expect_equal(dataset_resolution("something_P1D-m")$temporal, "daily")
  expect_equal(dataset_resolution("no_resolution_here")$spatial, "unknown")
  expect_equal(dataset_resolution("no_resolution_here")$temporal, "unknown")
})

test_that("the reference table carries a resolution for every covariate", {
  info <- covariate_info(include_derived = TRUE)

  expect_true(all(c("spatial", "temporal") %in% names(info)))
  expect_false(any(is.na(info$spatial) | !nzchar(info$spatial)))
  expect_false(any(is.na(info$temporal) | !nzchar(info$temporal)))

  # The two grids the pipeline actually has to reconcile.
  expect_equal(info$spatial[info$name == "SST"], "0.083° (~9 km)")
  expect_equal(info$spatial[info$name == "CHL"], "4 km (~0.036°)")
  expect_equal(info$temporal[info$name == "DEPTH"], "static")
})
