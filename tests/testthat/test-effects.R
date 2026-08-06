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
