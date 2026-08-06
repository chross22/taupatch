# A fine product and a coarse one, as two separately fetched objects. Values are
# distinguishable per month so a step that ignored time shows up as a wrong
# number rather than a subtly different one.
fine_product <- function(months = 1:2, res = 0.1, var = "SST") {
  do.call(rbind, lapply(months, function(m) {
    g <- expand.grid(x = seq(-70, -69, by = res), y = seq(42, 43, by = res))
    g[[var]] <- 10 + m
    g$YEAR <- 2020L; g$MONTH <- as.integer(m); g$DAY <- 1L
    sf::st_as_sf(g, coords = c("x", "y"), crs = 4326)
  }))
}

coarse_product <- function(months = 1:2, res = 0.5, var = "CHL", gaps = FALSE) {
  do.call(rbind, lapply(months, function(m) {
    g <- expand.grid(x = seq(-70, -69, by = res), y = seq(42, 43, by = res))
    g[[var]] <- 100 * m
    if (gaps) g[[var]][seq(1, nrow(g), by = 3)] <- NA_real_
    g$YEAR <- 2020L; g$MONTH <- as.integer(m); g$DAY <- 1L
    sf::st_as_sf(g, coords = c("x", "y"), crs = 4326)
  }))
}

prejoin_config <- function(steps, selected = c("SST", "CHL")) {
  config <- mock_config()
  config$covariates$selected <- selected
  config$covariates$prejoin <- steps
  config
}

test_that("every step type describes itself and names a real datamatch function", {
  catalog <- prejoin_steps()

  expect_gt(length(catalog), 0)
  for (name in names(catalog)) {
    entry <- catalog[[name]]
    expect_true(nzchar(entry$label %||% ""), info = name)
    expect_true(nzchar(entry$description %||% ""), info = name)
    expect_type(entry$fun, "closure")
    expect_true(length(entry$targets) >= 1)
  }

  # The functions this delegates to must actually be exported by datamatch, or
  # a config naming a step validates and then dies mid-fetch.
  for (fn in c("upscale_grid", "downscale_grid", "fill_satellite_gaps")) {
    expect_true(fn %in% getNamespaceExports("datamatch"), info = fn)
  }
})

test_that("a covariate is brought onto another covariate's grid", {
  per_dataset <- list(fine_product(), coarse_product())
  config <- prejoin_config(list(
    list(type = "upscale", covariate = "SST", to = "CHL", method = "mean")
  ))

  out <- suppressMessages(apply_prejoin_steps(per_dataset, config))

  sst <- Filter(function(x) "SST" %in% datamatch::covariate_columns(x), out)[[1]]
  # Named as a covariate, `to` means that covariate's grid - which is how a
  # config says "put this where the chlorophyll is" without hardcoding 0.5.
  expect_equal(unname(grid_spacing(sst)), 0.5)
  expect_equal(unname(grid_spacing(coarse_product())), 0.5)

  # Both time steps survive, with their own values.
  expect_setequal(unique(sst$MONTH), 1:2)
  expect_equal(round(mean(sst$SST[sst$MONTH == 1])), 11)
  expect_equal(round(mean(sst$SST[sst$MONTH == 2])), 12)
})

test_that("downscaling puts a coarse covariate on a finer grid", {
  per_dataset <- list(fine_product(), coarse_product())
  config <- prejoin_config(list(
    list(type = "downscale", covariate = "CHL", to = "SST", method = "nearest")
  ))

  out <- suppressMessages(apply_prejoin_steps(per_dataset, config))
  chl <- Filter(function(x) "CHL" %in% datamatch::covariate_columns(x), out)[[1]]

  expect_equal(unname(grid_spacing(chl)), 0.1)
  # `nearest` replicates rather than interpolating, so the original two values
  # are all that should be present.
  expect_setequal(unique(stats::na.omit(chl$CHL)), c(100, 200))
})

test_that("a target given as a number is a resolution in degrees", {
  per_dataset <- list(fine_product())
  config <- prejoin_config(list(
    list(type = "upscale", covariate = "SST", to = 0.5, method = "mean")
  ), selected = "SST")

  out <- suppressMessages(apply_prejoin_steps(per_dataset, config))

  expect_equal(unname(grid_spacing(out[[1]])), 0.5)
})

test_that("resampling one covariate does not drop the others sharing its product", {
  # datamatch::upscale_grid() returns only the columns it was asked to resample,
  # so regridding in place would silently discard the rest of the product. The
  # covariate has to be split out first.
  shared <- fine_product()
  shared$SSS <- 33
  per_dataset <- list(shared, coarse_product())

  config <- prejoin_config(list(
    list(type = "upscale", covariate = "SST", to = "CHL", method = "mean")
  ), selected = c("SST", "SSS", "CHL"))

  out <- suppressMessages(apply_prejoin_steps(per_dataset, config))
  carried <- unlist(lapply(out, datamatch::covariate_columns))

  expect_setequal(carried, c("SST", "SSS", "CHL"))

  # SSS stays on the grid it was fetched on; only SST moved.
  sss <- Filter(function(x) "SSS" %in% datamatch::covariate_columns(x), out)[[1]]
  sst <- Filter(function(x) "SST" %in% datamatch::covariate_columns(x), out)[[1]]
  expect_equal(unname(grid_spacing(sss)), 0.1)
  expect_equal(unname(grid_spacing(sst)), 0.5)
})

test_that("gaps are filled from another covariate, and the source is consumed", {
  satellite <- coarse_product(res = 0.25, var = "CHL", gaps = TRUE)
  model <- coarse_product(res = 0.5, var = "CHL_MODEL")
  per_dataset <- list(satellite, model)

  config <- prejoin_config(list(
    list(type = "fill_gaps", covariate = "CHL", from = "CHL_MODEL")
  ), selected = c("CHL", "CHL_MODEL"))

  expect_true(any(is.na(satellite$CHL)))
  out <- suppressMessages(apply_prejoin_steps(per_dataset, config))
  carried <- unlist(lapply(out, datamatch::covariate_columns))

  chl <- Filter(function(x) "CHL" %in% datamatch::covariate_columns(x), out)[[1]]
  expect_false(any(is.na(chl$CHL)))

  # The model was fetched to fill the satellite, not to be a second predictor
  # nearly identical to it.
  expect_false("CHL_MODEL" %in% carried)
  # Which source each value came from survives, so an analysis can tell an
  # observed cell from a simulated one.
  expect_true("CHL_source" %in% carried)
  expect_setequal(as.character(unique(chl$CHL_source)), c("satellite", "model"))
})

test_that("keep_source retains the filling covariate", {
  per_dataset <- list(coarse_product(res = 0.25, gaps = TRUE),
                      coarse_product(res = 0.5, var = "CHL_MODEL"))
  config <- prejoin_config(list(
    list(type = "fill_gaps", covariate = "CHL", from = "CHL_MODEL",
         keep_source = TRUE)
  ), selected = c("CHL", "CHL_MODEL"))

  out <- suppressMessages(apply_prejoin_steps(per_dataset, config))

  expect_true("CHL_MODEL" %in% unlist(lapply(out, datamatch::covariate_columns)))
})

test_that("a consumed source cannot be named as a predictor elsewhere", {
  config <- prejoin_config(list(
    list(type = "fill_gaps", covariate = "CHL", from = "CHL_MODEL")
  ), selected = c("SST", "CHL", "CHL_MODEL"))

  expect_equal(prejoin_dropped(config), "CHL_MODEL")

  # It is gone before the join, so nothing downstream can use it.
  config$covariates$transform <- list(log1p = "CHL_MODEL")
  expect_error(validate_covariates(config), "not selected")

  config$covariates$transform <- list()
  config$covariates$derivoce <- list(
    list(type = "horizontal_gradient", vars = "CHL_MODEL")
  )
  expect_error(validate_covariates(config), "no earlier step")

  # Keeping it makes both legal again.
  config$covariates$prejoin[[1]]$keep_source <- TRUE
  expect_true(validate_covariates(config))
})

test_that("steps chain, so a later one sees what an earlier one produced", {
  per_dataset <- list(fine_product(),
                      coarse_product(res = 0.25, gaps = TRUE),
                      coarse_product(res = 0.5, var = "CHL_MODEL"))
  config <- prejoin_config(list(
    list(type = "fill_gaps", covariate = "CHL", from = "CHL_MODEL"),
    list(type = "downscale", covariate = "CHL", to = "SST", method = "nearest")
  ), selected = c("SST", "CHL", "CHL_MODEL"))

  out <- suppressMessages(apply_prejoin_steps(per_dataset, config))
  chl <- Filter(function(x) "CHL" %in% datamatch::covariate_columns(x), out)[[1]]

  # Filled first, then regridded - so the result is both gap-free and fine.
  expect_false(any(is.na(chl$CHL)))
  expect_equal(unname(grid_spacing(chl)), 0.1)
})

test_that("config validation rejects malformed prejoin blocks", {
  expect_error(validate_covariates(prejoin_config(list(list(covariate = "SST")))),
               "needs a 'type'")
  expect_error(validate_covariates(prejoin_config(list(list(type = "regrid")))),
               "Unknown covariates.prejoin type")
  expect_error(
    validate_covariates(prejoin_config(list(list(type = "upscale", covariate = "SST")))),
    "needs 'to'"
  )
  expect_error(
    validate_covariates(prejoin_config(list(
      list(type = "upscale", covariate = "SST", to = "NOPE")
    ))),
    "covariates.selected does not fetch"
  )
  expect_error(
    validate_covariates(prejoin_config(list(
      list(type = "upscale", covariate = "SST", to = -1)
    ))),
    "positive resolution"
  )
  expect_error(
    validate_covariates(prejoin_config(list(
      list(type = "upscale", covariate = "SST", to = "SST")
    ))),
    "both its subject and its target"
  )
})

test_that("a step naming an unfetched covariate is reported against what was fetched", {
  per_dataset <- list(fine_product())
  config <- prejoin_config(list(
    list(type = "upscale", covariate = "CHL", to = 0.5)
  ), selected = c("SST", "CHL"))

  expect_error(apply_prejoin_steps(per_dataset, config),
               "no fetched product carries")
})

test_that("a prejoin block survives being read from a config file", {
  dir <- tempfile("configs"); dir.create(dir)
  path <- generate_config(
    "prej", dir = dir, zoop_file = "data/absent.csv",
    selected = c("SST", "CHL"), bathymetry = character(), transform = list(),
    prejoin = list(list(type = "upscale", covariate = "CHL", to = "SST",
                        method = "median"))
  )
  config <- load_config(path)

  expect_length(config$covariates$prejoin, 1)
  expect_equal(config$covariates$prejoin[[1]]$method, "median")
})

test_that("the source column does not break the covariate summary", {
  # covariate_monthly_means() averages every covariate column, and gap-filling
  # adds a factor recording where each value came from.
  env <- coarse_product(res = 0.5)
  env$CHL_source <- factor("satellite", levels = c("satellite", "model"))

  means <- covariate_monthly_means(env)

  expect_setequal(unique(means$covariate), "CHL")
  expect_false(any(is.na(means$mean)))
})

test_that("resampling before the join leaves the join nothing to upsample", {
  # The payoff. Without a prejoin step the join puts the coarse product onto the
  # fine grid by replication, and records it as upsampled - which is what makes
  # a gradient computed from it an artifact. Resampling first means the two
  # grids already agree, so nothing is replicated.
  fine <- fine_product()
  coarse <- coarse_product()

  spacing <- vapply(list(fine, coarse), grid_spacing, numeric(1))
  joined_raw <- Reduce(join_covariate_sources, list(fine, coarse)[order(spacing)])
  # 121 fine cells per step against 9 coarse ones: chlorophyll is replicated.
  expect_equal(nrow(joined_raw), nrow(fine))
  expect_lt(length(unique(joined_raw$CHL)), length(unique(joined_raw$SST)) * 2)

  config <- prejoin_config(list(
    list(type = "upscale", covariate = "SST", to = "CHL", method = "mean")
  ))
  prepared <- suppressMessages(apply_prejoin_steps(list(fine, coarse), config))

  spacing <- vapply(prepared, grid_spacing, numeric(1))
  expect_equal(length(unique(spacing)), 1)

  joined <- Reduce(join_covariate_sources, prepared)
  expect_setequal(datamatch::covariate_columns(joined), c("SST", "CHL"))
  # Every row is a cell that exists in both products; none is a copy.
  expect_equal(nrow(joined), nrow(coarse))
})
