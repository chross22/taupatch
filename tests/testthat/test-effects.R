fitted_of_type <- function(type, dat = labeled_mock_data()) {
  config <- mock_config()
  config$model$type <- type
  config$model$trees <- 50
  config$model$cv_folds <- 3
  suppressWarnings(fit_patch_model(dat, config))
}

test_that("partial effects sweep every predictor and stay a probability", {
  skip_on_cran()
  model <- fitted_of_type("rf")

  effects <- partial_effects(model$workflow, model$model_data, model$predictors)

  expect_setequal(unique(effects$variable), model$predictors)
  expect_true(all(effects$probability >= 0 & effects$probability <= 1))
  expect_false(any(is.na(effects$probability)))
  # Quantile-spaced, so the sweep spans the data rather than a fixed range.
  sst <- effects[effects$variable == "SST", ]
  expect_equal(min(sst$value), min(model$model_data$SST), tolerance = 1e-6)
})

test_that("an integer predictor is swept as an integer", {
  skip_on_cran()
  # jday is an integer column and the recipe checks types on the way in, so a
  # double swept through it fails as a lossy cast rather than plotting.
  model <- fitted_of_type("rf")
  expect_true(is.integer(model$model_data$jday))

  effects <- partial_effects(model$workflow, model$model_data, model$predictors)

  expect_true("jday" %in% effects$variable)
  expect_gt(nrow(effects[effects$variable == "jday", ]), 1)
})

test_that("partial effects are produced for every model type", {
  skip_on_cran()
  dat <- labeled_mock_data()

  for (type in names(model_types())) {
    skip_if_not_installed(model_types()[[type]]$package)
    model <- fitted_of_type(type, dat)

    effects <- partial_effects(model$workflow, model$model_data, model$predictors)
    expect_setequal(unique(effects$variable), model$predictors)
    expect_s3_class(plot_partial_effects(effects), "ggplot")
  }
})

test_that("partial effects follow a planted relationship", {
  skip_on_cran()
  set.seed(2)
  n <- 400
  driver <- runif(n, 0, 10)
  model_data <- data.frame(
    driver = driver,
    noise = rnorm(n),
    patch = factor(ifelse(driver + rnorm(n) > 5, "patch", "non_patch"),
                   levels = c("patch", "non_patch"))
  )
  config <- mock_config()
  config$model$type <- "glm"
  fitted <- parsnip::fit(
    workflows::workflow() |>
      workflows::add_recipe(build_recipe(model_data, config)) |>
      workflows::add_model(build_model_spec(config)),
    data = model_data
  )

  effects <- partial_effects(fitted, model_data, c("driver", "noise"))
  driver_curve <- effects[effects$variable == "driver", ]

  # Patch probability was built to rise with the driver, so the curve must.
  expect_gt(driver_curve$probability[nrow(driver_curve)],
            driver_curve$probability[1])
  # And be flat in the predictor that carries nothing.
  noise_curve <- effects[effects$variable == "noise", ]
  expect_lt(diff(range(noise_curve$probability)),
            diff(range(driver_curve$probability)) / 2)
})

test_that("a GLM reports signed coefficients without the intercept", {
  skip_on_cran()
  model <- fitted_of_type("glm")

  coefficients <- glm_coefficients(model$workflow)

  expect_setequal(coefficients$variable, model$predictors)
  # The intercept is a baseline, not an effect, and its scale would squash the
  # rest of the plot.
  expect_false("(Intercept)" %in% coefficients$variable)
  expect_true(all(coefficients$lower < coefficients$upper))
  # Sorted by magnitude, so the strongest effect reads first.
  expect_equal(abs(coefficients$estimate), sort(abs(coefficients$estimate),
                                                 decreasing = TRUE))
  expect_s3_class(plot_glm_coefficients(coefficients), "ggplot")
})

test_that("a GAM reports effective degrees of freedom per smooth", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  model <- fitted_of_type("gam")

  terms <- gam_smooth_terms(model$workflow)

  expect_true(nrow(terms) > 0)
  expect_true(all(grepl("^s\\(", terms$term)))
  # edf of 1 means the smooth collapsed to a straight line; below 1 would mean
  # the summary was misread.
  expect_true(all(terms$edf >= 1 - 1e-6))
  expect_equal(terms$edf, sort(terms$edf, decreasing = TRUE))
})

test_that("the engine object comes out for anything that plots it directly", {
  skip_on_cran()
  # fancygam::plotSmooths() and friends take the mgcv fit, not the workflow.
  expect_s3_class(model_engine_fit(fitted_of_type("glm")), "glm")
  skip_if_not_installed("mgcv")
  expect_s3_class(model_engine_fit(fitted_of_type("gam")), "gam")

  # Accepts a workflow directly too, so it works on a model read back off disk.
  model <- fitted_of_type("glm")
  expect_s3_class(model_engine_fit(model$workflow), "glm")
})

test_that("each type writes the diagnostics that suit it", {
  skip_on_cran()
  dat <- labeled_mock_data()

  expected <- list(
    rf = character(),
    glm = "coefficients.csv",
    gam = "smooth_terms.csv"
  )
  for (type in names(expected)) {
    skip_if_not_installed(model_types()[[type]]$package)
    out <- tempfile("diag"); dir.create(out)
    suppressWarnings(write_effect_plots(fitted_of_type(type, dat), out))
    written <- list.files(out)

    # Partial effects for everything; the extras only where they mean something.
    expect_true(all(c("partial_effects.png", "partial_effects.csv") %in% written),
                info = type)
    expect_true(all(expected[[type]] %in% written), info = type)
    if (type == "rf") {
      expect_false(any(c("coefficients.csv", "smooth_terms.csv") %in% written))
    }
  }
})

test_that("a failed diagnostic warns rather than passing silently", {
  # An empty diagnostics directory looks the same whether the plot failed or
  # was never wanted, which is how a broken one goes unnoticed.
  expect_warning(result <- try_diagnostic(stop("no good"), "partial effects"),
                 "Could not produce partial effects")
  expect_null(result)
  expect_equal(try_diagnostic(42, "something"), 42)
})

test_that("the smoothed variables are read back off the fitted model", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  model <- fitted_of_type("gam")

  smoothed <- gam_smoothed_variables(model$workflow)

  # Read back rather than assumed: model_formula() gives a linear term to any
  # predictor with too few distinct values to identify a smooth, so the two
  # sets are not always the same.
  expect_true(all(smoothed %in% model$predictors))
  expect_gt(length(smoothed), 0)
  # Names, not "s(name)".
  expect_false(any(grepl("^s\\(", smoothed)))
})

test_that("fancygam draws the fitted smooths for a GAM", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  skip_if_not_installed("fancygam")
  model <- fitted_of_type("gam")

  plot <- suppressMessages(plot_gam_smooths(model))
  expect_s3_class(plot, "ggplot")

  # Accepts a workflow directly, so it works on a model read back off disk.
  expect_s3_class(suppressMessages(plot_gam_smooths(model$workflow)), "ggplot")

  # And writes into the run's diagnostics alongside the generic curves.
  out <- tempfile("diag"); dir.create(out)
  suppressMessages(suppressWarnings(write_effect_plots(model, out)))
  expect_true("gam_smooths.png" %in% list.files(out))
})

test_that("smooth plots are drawn against the data the model actually saw", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  skip_if_not_installed("fancygam")
  model <- fitted_of_type("gam")

  # gratia reports the smooths in the recipe's output units, so the rug has to
  # come from the same baked frame. Taking it from the raw model_data would
  # draw the two on different x scales and quietly disagree.
  baked <- workflows::extract_mold(model$workflow)$predictors
  expect_setequal(names(baked), model$predictors)
  # Normalizing is on by default, so the baked columns are centred.
  expect_lt(abs(mean(baked$SST)), 1e-6)
  expect_gt(abs(mean(model$model_data$SST)), 1)
})

test_that("without fancygam the run still gets its generic curves", {
  skip_on_cran()
  skip_if_not_installed("mgcv")
  # fancygam is a Suggests: its absence removes the extra plot, not the
  # diagnostics.
  local_mocked_bindings(has_fancygam = function() FALSE)
  out <- tempfile("diag"); dir.create(out)
  suppressMessages(suppressWarnings(write_effect_plots(fitted_of_type("gam"), out)))
  written <- list.files(out)

  expect_false("gam_smooths.png" %in% written)
  expect_true("partial_effects.png" %in% written)
  expect_true("smooth_terms.csv" %in% written)
})

test_that("maps draw, not just build", {
  skip_on_cran()
  # geom_sf() refuses to work under any coord but coord_sf(), and refuses when
  # the grobs are made rather than when the plot is assembled. ggplot_build()
  # passes and the app shows an error, so these have to be drawn to a device.
  config <- mock_config()
  generate_mock_zoop_data(config)
  dat <- load_zoop_data(config)
  env <- fetch_covariates(config, years = 2018, months = 6)

  drawn <- function(plot) {
    file <- tempfile(fileext = ".png")
    grDevices::png(file, width = 500, height = 400)
    on.exit(grDevices::dev.off(), add = TRUE)
    print(plot)
    TRUE
  }

  expect_true(drawn(plot_station_map(dat)))
  expect_true(drawn(plot_covariate_map(env, "SST", 2018, 6)))
  expect_true(drawn(plot_station_series(dat)))
})

test_that("abundance over the record is one continuous series", {
  skip_on_cran()
  config <- mock_config()
  generate_mock_zoop_data(config)
  dat <- load_zoop_data(config)

  p <- plot_station_series(dat)
  built <- ggplot2::ggplot_build(p)

  # A station sits at its own year and month rather than being collapsed onto
  # one or the other, so the axis is continuous and spans the record.
  x <- built$data[[1]]$x
  expect_gt(diff(range(x)), 0.5)
  expect_true(all(x >= min(dat$year) & x <= max(dat$year) + 1))

  # Points only. A line joining sampled months draws a trajectory through the
  # ones nobody sailed in.
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_false("GeomLine" %in% geoms)
  expect_true(all(geoms %in% c("GeomPoint", "GeomJitter")))
})
