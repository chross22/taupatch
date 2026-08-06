# Labeled modeling data is built once: fitting four model types against the
# same stations is the point, and rebuilding it per test would be most of the
# runtime of this file.
typed_data <- local({
  cached <- NULL
  function() {
    if (is.null(cached)) cached <<- labeled_mock_data()
    cached
  }
})

test_that("every model type describes itself and names a real parsnip engine", {
  catalog <- model_types()

  expect_setequal(names(catalog), c("rf", "brt", "glm", "gam"))
  for (name in names(catalog)) {
    entry <- catalog[[name]]
    expect_true(nzchar(entry$label %||% ""), info = name)
    expect_true(nzchar(entry$description %||% ""), info = name)
    expect_type(entry$spec, "closure")
    expect_type(entry$needs_formula, "logical")
  }

  # Only the GAM needs a formula; if that ever changed silently, three of the
  # four would be fitted without their smooth terms.
  expect_true(catalog$gam$needs_formula)
  expect_false(any(vapply(catalog[c("rf", "brt", "glm")],
                          function(m) m$needs_formula, logical(1))))
})

test_that("the model type comes from model.type", {
  config <- mock_config()

  for (type in names(model_types())) {
    config$model$type <- type
    expect_equal(resolve_model_type(config), type)
  }

  config$model$type <- "randomforest"
  expect_error(resolve_model_type(config), "Unknown model.type")
})

test_that("a config predating model.type still means what it meant", {
  # Those configs say only `engine: ranger`, and used to fit a random forest.
  config <- mock_config()
  config$model$type <- NULL
  config$model$engine <- "ranger"
  expect_equal(resolve_model_type(config), "rf")

  config$model$engine <- "xgboost"
  expect_equal(resolve_model_type(config), "brt")

  # And with neither, the default is the model the package has always fitted.
  config$model$engine <- NULL
  expect_equal(resolve_model_type(config), "rf")

  config$model$engine <- "glmnet"
  expect_error(resolve_model_type(config), "does not identify a model type")
})

test_that("each type builds a spec for its own engine", {
  config <- mock_config()
  config$model$tune <- FALSE

  for (type in names(model_types())) {
    config$model$type <- type
    spec <- build_model_spec(config)

    expect_equal(spec$engine, model_types()[[type]]$engine, info = type)
    expect_equal(spec$mode, "classification", info = type)
    # Nothing is tagged for tuning when tuning is off, whichever type it is.
    expect_length(tune::tune_args(spec)$name, 0)
  }
})

test_that("the GAM formula smooths only what can support a smooth", {
  model_data <- data.frame(
    SST = rnorm(60),                 # continuous; gets a smooth
    flag = rep(c(0, 1), each = 30),  # two distinct values; cannot
    patch = factor(rep(c("patch", "non_patch"), 30),
                   levels = c("patch", "non_patch"))
  )

  formula <- model_formula("gam", model_data, c("SST", "flag"))
  text <- paste(deparse(formula), collapse = "")

  expect_match(text, "s(SST)", fixed = TRUE)
  # A thin-plate spline needs more unique points than basis functions, so a
  # near-constant column enters linearly rather than failing.
  expect_false(grepl("s(flag)", text, fixed = TRUE))
  expect_match(text, "flag")

  # The types that do not need one get nothing, not an empty formula.
  expect_null(model_formula("rf", model_data, "SST"))
})

test_that("all four types fit, score, and rank their predictors", {
  skip_on_cran()
  dat <- typed_data()

  for (type in names(model_types())) {
    skip_if_not_installed(model_types()[[type]]$package)
    config <- mock_config()
    config$model$type <- type
    config$model$trees <- 50
    config$model$cv_folds <- 3

    model <- suppressWarnings(fit_patch_model(dat, config))

    expect_equal(model$type, type)
    auc <- model$metrics$mean[model$metrics$.metric == "roc_auc"]
    # The mock data plants a real signal, so any working model beats chance.
    expect_gt(auc, 0.6, label = paste(type, "ROC AUC"))
    expect_setequal(model$importance$variable, model$predictors)
  }
})

test_that("importance is one definition across every type", {
  skip_on_cran()
  dat <- typed_data()

  # ranger's permutation drop and xgboost's split gain are different quantities
  # on different scales; read against each other they say nothing. Permuting
  # here means the numbers mean the same thing whichever model produced them.
  for (type in c("rf", "glm")) {
    config <- mock_config()
    config$model$type <- type
    config$model$trees <- 50
    config$model$cv_folds <- 3

    importance <- suppressWarnings(fit_patch_model(dat, config))$importance

    # A drop in AUC, so it is sorted and the best predictor is a real loss.
    expect_equal(importance$importance, sort(importance$importance, decreasing = TRUE))
    expect_gt(importance$importance[1], 0)
    expect_true(all(is.finite(importance$importance)))
  }
})

test_that("permutation importance finds the predictor that carries the signal", {
  skip_on_cran()
  set.seed(1)
  n <- 300
  signal <- rnorm(n)
  model_data <- data.frame(
    real = signal,
    noise = rnorm(n),
    # Informative but not separating: a perfectly separable predictor makes
    # the GLM diverge, and a diverged model's importance is not what is
    # being tested here.
    patch = factor(ifelse(signal + rnorm(n) > 0, "patch", "non_patch"),
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

  importance <- permutation_importance(fitted, model_data, c("real", "noise"))

  expect_equal(importance$variable[1], "real")
  expect_gt(importance$importance[importance$variable == "real"], 0.1)
  # Shuffling a predictor the model never used costs nothing.
  expect_lt(abs(importance$importance[importance$variable == "noise"]), 0.05)
})

test_that("a missing engine package is reported against the type that needs it", {
  expect_true(check_model_packages("glm"))   # stats is always there

  local_mocked_bindings(
    model_types = function() {
      catalog <- list(rf = list(label = "Random forest", package = "notapackage",
                                engine = "ranger", tunable = character(),
                                needs_formula = FALSE, spec = function(...) NULL))
      catalog
    }
  )
  expect_error(check_model_packages("rf"), "notapackage")
})
