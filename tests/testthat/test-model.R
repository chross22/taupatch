test_that("build_model_spec does not tag arguments for tuning when tune is FALSE", {
  # parsnip captures arguments as quosures, so passing `if (tuning) tune() else x`
  # directly stores the unevaluated expression and parsnip sees a literal tune()
  # in it, tagging the argument for tuning even when tuning is off.
  config <- mock_config()
  config$model$tune <- FALSE

  spec <- build_model_spec(config)

  expect_length(tune::tune_args(spec)$name, 0)
})

test_that("build_model_spec tags arguments for tuning when tune is TRUE", {
  config <- mock_config()
  config$model$tune <- TRUE

  spec <- build_model_spec(config)

  expect_setequal(tune::tune_args(spec)$name, c("mtry", "min_n"))
})

test_that("the recipe log-transforms only the named covariates", {
  config <- mock_config()
  config$covariates$log_transform <- "thetao"

  model_data <- data.frame(
    thetao = c(1, 9, 99),
    so = c(1, 9, 99),
    patch = factor(c("patch", "non_patch", "patch"), levels = c("patch", "non_patch"))
  )

  baked <- build_recipe(model_data, config) |>
    recipes::prep() |>
    recipes::bake(new_data = NULL)

  normalize <- function(x) as.numeric(scale(x))
  expect_equal(baked$thetao, normalize(log1p(abs(c(1, 9, 99)))))
  expect_equal(baked$so, normalize(c(1, 9, 99)))
})

test_that("the log transform is defined at zero and for negative values", {
  # Bathymetry is stored as negative depth and chlorophyll can be zero, so the
  # transform must not produce -Inf or NaN for either.
  config <- mock_config()
  config$covariates$log_transform <- c("chl", "bat")

  model_data <- data.frame(
    chl = c(0, 1, 5),
    bat = c(-200, -50, -1),
    patch = factor(c("patch", "non_patch", "patch"), levels = c("patch", "non_patch"))
  )

  baked <- build_recipe(model_data, config) |>
    recipes::prep() |>
    recipes::bake(new_data = NULL)

  expect_true(all(is.finite(baked$chl)))
  expect_true(all(is.finite(baked$bat)))
})

test_that("add_tss derives TSS from sensitivity and specificity", {
  metrics <- tibble::tibble(
    .metric = c("sens", "spec"),
    .estimator = "binary",
    mean = c(0.8, 0.9),
    n = 5L,
    std_err = c(0.01, 0.02)
  )

  result <- add_tss(metrics)

  expect_true("tss" %in% result$.metric)
  expect_equal(result$mean[result$.metric == "tss"], 0.7)
})

test_that("add_tss leaves metrics untouched when sens/spec are absent", {
  metrics <- tibble::tibble(.metric = "roc_auc", .estimator = "binary",
                            mean = 0.9, n = 5L, std_err = 0.01)

  expect_equal(add_tss(metrics), metrics)
})

test_that("held-out predictions are retained for diagnostics", {
  skip_if_not_installed("ranger")

  config <- mock_config()
  dat <- labeled_mock_data(config)
  model <- fit_patch_model(dat, config)

  # Without save_pred the curves would have to be drawn on training data, which
  # flatters the model.
  expect_true(nrow(model$predictions) > 0)
  expect_true(all(c(".pred_patch", "patch", "id") %in% names(model$predictions)))
  # One row per observation per fold assignment: every station held out once.
  expect_equal(nrow(model$predictions), nrow(dat))
})

test_that("the classification threshold maximises TSS, not accuracy at 0.5", {
  skip_if_not_installed("ranger")

  config <- mock_config()
  dat <- labeled_mock_data(config)
  model <- fit_patch_model(dat, config)

  cutoff <- model$classification_threshold
  expect_true(is.finite(cutoff))
  expect_true(cutoff > 0 && cutoff < 1)

  # It must beat 0.5 on TSS, which is the whole reason for computing it: with a
  # tenth of stations as patches, 0.5 calls almost nothing a patch.
  tss_at <- function(threshold) {
    called <- model$predictions$.pred_patch >= threshold
    is_patch <- model$predictions$patch == "patch"
    sens <- sum(called & is_patch) / sum(is_patch)
    spec <- sum(!called & !is_patch) / sum(!is_patch)
    sens + spec - 1
  }
  expect_gte(tss_at(cutoff), tss_at(0.5))
})

test_that("diagnostic plots are produced from held-out predictions", {
  skip_if_not_installed("ranger")

  config <- mock_config()
  dat <- labeled_mock_data(config)
  model <- fit_patch_model(dat, config)

  expect_s3_class(plot_roc_curve(model$predictions), "ggplot")
  expect_s3_class(plot_pr_curve(model$predictions), "ggplot")
  expect_s3_class(plot_calibration(model$predictions), "ggplot")
  expect_s3_class(plot_threshold_performance(model$predictions), "ggplot")
})

test_that("diagnostic plots refuse to draw without predictions", {
  expect_error(plot_roc_curve(NULL), "No held-out predictions")
  expect_error(plot_pr_curve(data.frame()), "No held-out predictions")
  expect_error(plot_calibration(data.frame(x = 1)), "Expected a '.pred_patch'")
})

test_that("the evaluation table states which cutoff each metric belongs to", {
  skip_if_not_installed("ranger")

  config <- mock_config()
  model <- fit_patch_model(labeled_mock_data(config), config)
  evaluation <- model$evaluation

  expect_setequal(names(evaluation),
                  c("metric", "threshold", "value", "std_err", "note"))

  # Ranking metrics have no cutoff, and saying NA is the honest entry.
  expect_true(all(is.na(evaluation$threshold[evaluation$metric %in%
                                               c("roc_auc", "pr_auc")])))
  # Everything else must name one.
  threshold_dependent <- evaluation$metric %in% c("sens", "spec", "tss", "precision")
  expect_false(any(is.na(evaluation$threshold[threshold_dependent])))
})

test_that("threshold-dependent metrics are reported at both cutoffs", {
  skip_if_not_installed("ranger")

  config <- mock_config()
  model <- fit_patch_model(labeled_mock_data(config), config)
  evaluation <- model$evaluation

  cutoffs <- sort(unique(evaluation$threshold[!is.na(evaluation$threshold)]))
  expect_length(cutoffs, 2)
  expect_true(0.5 %in% cutoffs)
  expect_true(model$classification_threshold %in% cutoffs)

  # Each of the four appears once per cutoff.
  for (metric in c("sens", "spec", "tss", "precision")) {
    expect_equal(sum(evaluation$metric == metric), 2, info = metric)
  }
})

test_that("the optimal cutoff beats 0.5 on TSS, which is the point of showing both", {
  skip_if_not_installed("ranger")

  config <- mock_config()
  model <- fit_patch_model(labeled_mock_data(config), config)
  evaluation <- model$evaluation

  tss <- evaluation[evaluation$metric == "tss", ]
  at_default <- tss$value[tss$threshold == 0.5]
  at_best <- tss$value[tss$threshold != 0.5]

  expect_gte(at_best, at_default)

  # And sensitivity is the metric the default understates: at 0.5 a random
  # forest calls almost nothing a patch when a tenth of stations are patches.
  sens <- evaluation[evaluation$metric == "sens", ]
  expect_gt(sens$value[sens$threshold != 0.5], sens$value[sens$threshold == 0.5])
})

test_that("metrics_at computes sensitivity and specificity directly", {
  predictions <- data.frame(
    .pred_patch = c(0.9, 0.8, 0.2, 0.1, 0.7),
    patch = factor(c("patch", "patch", "non_patch", "non_patch", "non_patch"),
                   levels = c("patch", "non_patch"))
  )

  at_half <- metrics_at(predictions, 0.5)

  # Both patches are above 0.5, so sensitivity is 1. One of three non-patches
  # is above it, so specificity is 2/3.
  expect_equal(at_half$value[at_half$metric == "sens"], 1)
  expect_equal(at_half$value[at_half$metric == "spec"], 2 / 3)
  expect_equal(at_half$value[at_half$metric == "tss"], 2 / 3)
  # Three cells called patch, two of them real.
  expect_equal(at_half$value[at_half$metric == "precision"], 2 / 3)
})

test_that("an uncomputable cutoff yields no threshold-dependent rows", {
  predictions <- data.frame(.pred_patch = numeric(), patch = factor())

  expect_equal(nrow(metrics_at(predictions, NA_real_)), 0)
})
