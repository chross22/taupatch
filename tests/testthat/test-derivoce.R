# A covariate grid with the variables the derivoce steps below read, on a real
# regular grid so the raster-based steps have something to work with.
derivoce_config <- function(steps) {
  config <- mock_config()
  config$covariates$selected <- c("SST", "SSS", "CHL", "UO", "VO")
  config$covariates$derivoce <- steps
  config
}

test_that("every catalog entry describes itself and its outputs", {
  catalog <- derivoce_covariates()

  expect_gt(length(catalog), 0)
  for (name in names(catalog)) {
    entry <- catalog[[name]]
    for (field in c("label", "units", "description")) {
      expect_true(nzchar(entry[[field]] %||% ""),
                  info = paste(name, "is missing", field))
    }
    expect_type(entry$outputs, "closure")
    expect_type(entry$neighbourhood, "logical")
  }

  # Every type must be a function derivoce actually exports, or a config naming
  # it validates cleanly and then fails mid-run.
  skip_if_not_installed("derivoce")
  expect_true(all(names(catalog) %in% getNamespaceExports("derivoce")))
})

test_that("the reference table describes derived covariates alongside fetched ones", {
  info <- covariate_info(include_derived = TRUE)

  expect_true(all(names(derivoce_covariates()) %in% info$name))
  expect_false(any(names(derivoce_covariates()) %in%
                     covariate_info(include_derived = FALSE)$name))
})

test_that("predicted column names match the columns derivoce produces", {
  skip_if_not_installed("derivoce")
  # The whole point of predicting names before a run: log_transform and config
  # validation refer to columns that do not exist yet. If the two drift apart,
  # a config that validates produces a model missing a predictor.
  config <- derivoce_config(list(
    list(type = "horizontal_gradient", vars = c("SST", "SSS")),
    list(type = "vertical_gradient", surface = "SST", bottom = "SSS", name = "strat"),
    list(type = "temporal_gradient", vars = "SST", per = "month"),
    list(type = "lag_covariate", vars = "CHL", n = 2),
    list(type = "integrate_covariate", vars = "CHL"),
    list(type = "current_speed"),
    list(type = "eke")
  ))

  env <- fetch_covariates(config, years = 2018, months = 6:8)
  derived <- suppressMessages(add_derivoce_covariates(env, config))

  expect_setequal(setdiff(names(derived), names(env)), derivoce_names(config))
  expect_setequal(
    derivoce_names(config),
    c("SST_grad", "SSS_grad", "strat", "SST_tgrad", "CHL_lag2", "CHL_int",
      "speed", "EKE")
  )
})

test_that("derived covariates carry real values, not just columns", {
  skip_if_not_installed("derivoce")
  config <- derivoce_config(list(
    list(type = "current_speed"),
    list(type = "lag_covariate", vars = "SST", n = 1)
  ))

  env <- fetch_covariates(config, years = 2018, months = 6:8)
  derived <- suppressMessages(add_derivoce_covariates(env, config))
  flat <- sf::st_drop_geometry(derived)

  expect_equal(flat$speed, sqrt(flat$UO^2 + flat$VO^2))

  # The lag is undefined in the first step and equals the previous step's value
  # after it, matched by location rather than row order.
  expect_true(all(is.na(flat$SST_lag1[flat$MONTH == 6])))
  expect_false(any(is.na(flat$SST_lag1[flat$MONTH == 7])))
  expect_equal(sort(flat$SST_lag1[flat$MONTH == 7]), sort(flat$SST[flat$MONTH == 6]))
})

test_that("steps chain, so a step can read what an earlier one produced", {
  skip_if_not_installed("derivoce")
  # current_speed then a gradient of `speed` is the original pipeline's uv_grad.
  config <- derivoce_config(list(
    list(type = "current_speed"),
    list(type = "horizontal_gradient", vars = "speed", suffix = "_grad")
  ))

  env <- fetch_covariates(config, years = 2018, months = 6)
  derived <- suppressMessages(add_derivoce_covariates(env, config))

  expect_true("speed_grad" %in% names(derived))
  expect_true(any(!is.na(derived$speed_grad)))
  expect_true(validate_covariates(config))
})

test_that("a step reading something no earlier step produces is caught up front", {
  # Reversing the order above: the gradient now runs before speed exists.
  config <- derivoce_config(list(
    list(type = "horizontal_gradient", vars = "speed"),
    list(type = "current_speed")
  ))

  expect_error(validate_covariates(config), "speed")
  expect_error(validate_covariates(config), "no earlier step")
})

test_that("config validation rejects malformed steps", {
  expect_error(validate_covariates(derivoce_config(list(list(vars = "SST")))),
               "needs a 'type'")
  expect_error(validate_covariates(derivoce_config(list(list(type = "nope")))),
               "Unknown covariates.derivoce type")
  # Required fields, both the covariate-naming kind and the plain kind.
  expect_error(validate_covariates(derivoce_config(list(list(type = "horizontal_gradient")))),
               "needs 'vars'")
  expect_error(
    validate_covariates(derivoce_config(list(list(type = "distance_to_contour", var = "SST")))),
    "needs levels"
  )
  # A step that would silently replace a fetched covariate with a derived one.
  expect_error(
    validate_covariates(derivoce_config(list(
      list(type = "vertical_gradient", surface = "SST", bottom = "SSS", name = "CHL")
    ))),
    "overwrite"
  )
})

test_that("a bare string is a step with no arguments", {
  spec <- normalize_derivoce_spec("distance_to_shore")

  expect_equal(spec$type, "distance_to_shore")
  expect_equal(derivoce_covariates()$distance_to_shore$outputs(spec), "shore_dist")
})

test_that("an argument the derivoce function does not take is reported with the accepted ones", {
  skip_if_not_installed("derivoce")
  config <- derivoce_config(list(list(type = "lag_covariate", vars = "SST", lag = 2)))
  env <- fetch_covariates(config, years = 2018, months = 6:7)

  # 'lag' is a plausible guess at the argument spelled 'n'; the config is
  # otherwise valid, so this can only be caught where derivoce is available.
  expect_true(validate_covariates(config))
  expect_error(add_derivoce_covariates(env, config), "no argument\\(s\\) lag")
  expect_error(add_derivoce_covariates(env, config), "Accepted:.*\\bn\\b")
})

test_that("log_transform may name a derived covariate", {
  config <- derivoce_config(list(list(type = "integrate_covariate", vars = "CHL")))
  config$covariates$log_transform <- "CHL_int"
  expect_true(validate_covariates(config))

  config$covariates$log_transform <- "CHL_integrated"
  expect_error(validate_covariates(config), "not selected")
})

test_that("a neighbourhood step warns when its input was upsampled", {
  skip_if_not_installed("derivoce")
  config <- derivoce_config(list(
    list(type = "horizontal_gradient", vars = "CHL"),
    list(type = "lag_covariate", vars = "CHL")
  ))
  env <- fetch_covariates(config, years = 2018, months = 6:7)
  attr(env, "upsampled") <- "CHL"

  # The gradient of a variable repeated across a coarse cell describes the
  # source grid; the lag of the same variable is unaffected, so only one warns.
  expect_warning(derived <- suppressMessages(add_derivoce_covariates(env, config)),
                 "upsampled from a coarser product")
  expect_true(all(c("CHL_grad", "CHL_lag1") %in% names(derived)))
  # The record of which variables were upsampled survives for later stages.
  expect_equal(attr(derived, "upsampled"), "CHL")
})

test_that("a step needing bathymetry says so when none was fetched", {
  skip_if_not_installed("derivoce")
  config <- derivoce_config(list(
    list(type = "distance_to_isobath", levels = c(100, 200))
  ))
  config$covariates$bathymetry <- "DEPTH"
  env <- fetch_covariates(config, years = 2018, months = 6)

  expect_error(add_derivoce_covariates(env, config, bathy = NULL),
               "no bathymetry was fetched")
})

test_that("derived covariates reach the model and the projection grid", {
  skip_if_not_installed("derivoce")
  skip_if_not_installed("ranger")
  config <- derivoce_config(list(
    list(type = "horizontal_gradient", vars = "SST"),
    list(type = "vertical_gradient", surface = "SST", bottom = "SSS", name = "strat")
  ))
  generate_mock_zoop_data(config)

  result <- suppressMessages(run_taupatch(config, project = TRUE))

  expect_true(all(c("SST_grad", "strat") %in% result$model$predictors))
  expect_true(all(c("SST_grad", "strat") %in% result$model$importance$variable))
  expect_gt(nrow(result$projections), 0)

  # The grid a projection is made from carries the derived columns too, or the
  # model would be predicting on covariates it was not trained on.
  env <- suppressMessages(
    add_derivoce_covariates(fetch_covariates(config), config)
  )
  grid <- covariate_grid(env, config$projection$years[1], config$projection$months[1],
                         config)
  expect_true(all(result$model$predictors %in% names(grid)))
})

test_that("a derivoce block survives being read from a config file", {
  # Every other test here sets covariates$derivoce on an already-loaded config,
  # which skips apply_config_defaults(). It should not: modifyList() recurses
  # when both sides are lists and merges them by name, and a derivoce block is
  # an unnamed sequence of steps - so the default list() came back out and the
  # configured steps were silently dropped on load.
  path <- system.file("configs", "cfin_gom.yaml", package = "taupatch")
  if (!nzchar(path)) path <- test_path("..", "..", "inst", "configs", "cfin_gom.yaml")
  config <- load_config(path)

  expect_gt(length(config$covariates$derivoce), 0)
  expect_true(all(c("SST_grad", "CHL_lag1") %in% derivoce_names(config)))

  # And the same through a config the generator wrote.
  dir <- tempfile("configs"); dir.create(dir)
  generated <- generate_config(
    "roundtrip", dir = dir, zoop_file = "data/absent.csv",
    selected = c("SST", "BOTT"), bathymetry = character(), transform = list(),
    derivoce = list(list(type = "lag_covariate", vars = "SST", n = 2))
  )
  expect_equal(derivoce_names(load_config(generated)), "SST_lag2")
})

test_that("a run with no derivoce block is untouched", {
  config <- mock_config()

  expect_equal(config$covariates$derivoce, list())
  expect_equal(derivoce_names(config), character())

  env <- fetch_covariates(config, years = 2018, months = 6)
  expect_identical(add_derivoce_covariates(env, config), env)
})
