# A separable problem with a rare positive class, which is the shape this
# package always has: a 90th-percentile threshold makes a tenth of stations
# patches, and that is what makes 0.5 the wrong cutoff.
boot_predictions <- function(n = 400, prevalence = 0.1, seed = 1) {
  set.seed(seed)
  positives <- round(n * prevalence)
  data.frame(
    patch = factor(rep(c("patch", "non_patch"), c(positives, n - positives)),
                   levels = c("patch", "non_patch")),
    .pred_patch = c(stats::rbeta(positives, 5, 3),
                    stats::rbeta(n - positives, 2, 8))
  )
}

test_that("every metric gets an interval, including the ones with no std_err", {
  predictions <- boot_predictions()
  bounds <- bootstrap_evaluation(predictions, optimal_threshold(predictions),
                                  times = 300, seed = 1)

  # These four are computed from pooled predictions rather than per fold, so
  # they never had a standard error. Filling them in is the point of this.
  for (metric in c("pr_auc", "tss", "precision", "sens", "spec")) {
    rows <- bounds[bounds$metric == metric, ]
    expect_gt(nrow(rows), 0)
    expect_false(any(is.na(rows$lower)), info = metric)
    expect_false(any(is.na(rows$upper)), info = metric)
  }
})

test_that("intervals are ordered and stay on the scale of their metric", {
  predictions <- boot_predictions()
  bounds <- bootstrap_evaluation(predictions, optimal_threshold(predictions),
                                  times = 300, seed = 1)

  expect_true(all(bounds$lower <= bounds$upper, na.rm = TRUE))
  # Every metric here is a proportion or a probability, TSS included: it runs
  # -1 to 1, and the rest 0 to 1.
  expect_true(all(bounds$lower >= -1, na.rm = TRUE))
  expect_true(all(bounds$upper <= 1, na.rm = TRUE))
})

test_that("the interval brackets the point estimate it belongs to", {
  predictions <- boot_predictions(n = 800)
  cutoff <- optimal_threshold(predictions)
  bounds <- bootstrap_evaluation(predictions, cutoff, times = 500, seed = 2)

  point <- metrics_at(predictions, 0.5)
  for (metric in c("sens", "spec", "tss")) {
    interval <- bounds[bounds$metric == metric & bounds$threshold_kind == "default", ]
    value <- point$value[point$metric == metric]
    expect_gte(value, interval$lower)
    expect_lte(value, interval$upper)
  }
})

test_that("the optimal cutoff carries an interval of its own", {
  predictions <- boot_predictions(n = 800)
  cutoff <- optimal_threshold(predictions)
  bounds <- bootstrap_evaluation(predictions, cutoff, times = 500, seed = 3)

  interval <- bounds[bounds$metric == "classification_threshold", ]
  expect_equal(nrow(interval), 1)
  # It is estimated from the same predictions it then scores, so how much it
  # moves is worth knowing before binarising a map with it.
  expect_lt(interval$lower, interval$upper)
  expect_gte(cutoff, interval$lower)
  expect_lte(cutoff, interval$upper)
})

test_that("the cutoff is re-derived per resample rather than held fixed", {
  # Holding it fixed would understate the uncertainty at the optimal cutoff,
  # since a different sample would have picked a different cutoff. If the
  # cutoff were fixed its interval would collapse to a point.
  predictions <- boot_predictions(n = 400)
  bounds <- bootstrap_evaluation(predictions, optimal_threshold(predictions),
                                  times = 400, seed = 4)

  interval <- bounds[bounds$metric == "classification_threshold", ]
  expect_gt(interval$upper - interval$lower, 0)
})

test_that("a wider level gives a wider interval", {
  predictions <- boot_predictions(n = 600)
  cutoff <- optimal_threshold(predictions)

  narrow <- bootstrap_evaluation(predictions, cutoff, times = 400, level = 0.5,
                                  seed = 5)
  wide <- bootstrap_evaluation(predictions, cutoff, times = 400, level = 0.99,
                                seed = 5)

  narrow_width <- narrow$upper[narrow$metric == "roc_auc"] -
    narrow$lower[narrow$metric == "roc_auc"]
  wide_width <- wide$upper[wide$metric == "roc_auc"] -
    wide$lower[wide$metric == "roc_auc"]

  expect_gt(wide_width, narrow_width)
})

test_that("the seed makes the interval reproducible without moving the stream", {
  predictions <- boot_predictions()
  cutoff <- optimal_threshold(predictions)

  set.seed(99)
  before <- runif(1)

  set.seed(99)
  invisible(bootstrap_evaluation(predictions, cutoff, times = 200, seed = 7))
  # The evaluation must not consume the run's random stream: whatever is drawn
  # next has to be what would have been drawn anyway.
  expect_equal(runif(1), before)

  first <- bootstrap_evaluation(predictions, cutoff, times = 200, seed = 7)
  second <- bootstrap_evaluation(predictions, cutoff, times = 200, seed = 7)
  expect_equal(first, second)
})

test_that("a bootstrap that cannot run says so rather than inventing bounds", {
  expect_null(bootstrap_evaluation(NULL, 0.5))
  expect_null(bootstrap_evaluation(data.frame(x = 1), 0.5))

  # One class only: every metric here is undefined.
  single <- data.frame(patch = factor(rep("patch", 20),
                                       levels = c("patch", "non_patch")),
                       .pred_patch = runif(20))
  expect_null(bootstrap_evaluation(single, 0.5, times = 50))

  expect_null(bootstrap_evaluation(boot_predictions(), 0.5, times = 1))
})

# ---- the cutoff computation -------------------------------------------------

test_that("best_cutoff matches an ROC curve read the long way", {
  set.seed(11)
  for (i in 1:40) {
    n <- sample(40:300, 1)
    positives <- sample(5:(n - 5), 1)
    predictions <- data.frame(
      patch = factor(rep(c("patch", "non_patch"), c(positives, n - positives)),
                     levels = c("patch", "non_patch")),
      # Rounded, so there are ties: a cutoff cannot split equal probabilities,
      # and the tie handling is the part that is easy to get wrong.
      .pred_patch = round(runif(n), sample(1:3, 1))
    )

    curve <- yardstick::roc_curve(predictions, truth = "patch", ".pred_patch")
    curve <- curve[is.finite(curve$.threshold), ]
    from_curve <- curve$.threshold[
      which.max(curve$sensitivity + curve$specificity - 1)
    ]
    ours <- best_cutoff(predictions$patch == "patch", predictions$.pred_patch)

    # Ties can make two cutoffs equally optimal, so what has to match is the
    # TSS they achieve rather than the cutoff itself.
    tss_at <- function(cut) {
      scored <- metrics_at(predictions, cut)
      scored$value[scored$metric == "tss"]
    }
    expect_equal(tss_at(ours), tss_at(from_curve), tolerance = 1e-9)
  }
})

test_that("best_cutoff refuses a degenerate problem", {
  expect_true(is.na(best_cutoff(logical(0), numeric(0))))
  expect_true(is.na(best_cutoff(rep(TRUE, 5), runif(5))))
  expect_true(is.na(best_cutoff(rep(FALSE, 5), runif(5))))
})

# ---- config -----------------------------------------------------------------

test_that("model.bootstrap controls the resample count", {
  config <- mock_config()
  expect_equal(bootstrap_times(config), 2000L)

  config$model$bootstrap <- FALSE
  expect_equal(bootstrap_times(config), 0L)

  config$model$bootstrap <- 500
  expect_equal(bootstrap_times(config), 500L)

  # A percentile interval from a handful of resamples moves every run, so it
  # is refused rather than reported.
  config$model$bootstrap <- 10
  expect_error(bootstrap_times(config), "at least 100")

  config$model$bootstrap <- "lots"
  expect_error(bootstrap_times(config), "non-negative count")
})

test_that("turning the bootstrap off leaves the table without bounds", {
  skip_if_not_installed("ranger")

  config <- mock_config()
  config$model$bootstrap <- FALSE
  model <- fit_patch_model(labeled_mock_data(config), config)

  # The columns stay, so anything reading evals.csv sees the same shape either
  # way; they are simply empty.
  expect_true(all(c("lower", "upper") %in% names(model$evaluation)))
  expect_true(all(is.na(model$evaluation$lower)))
})

test_that("a fitted run fills in the metrics that had no uncertainty before", {
  skip_if_not_installed("ranger")

  config <- mock_config()
  config$model$bootstrap <- 300
  model <- fit_patch_model(labeled_mock_data(config), config)
  evaluation <- model$evaluation

  # pr_auc and tss never had a std_err, because they come from the pooled
  # predictions rather than from per-fold averages.
  gap <- evaluation$metric %in% c("pr_auc", "tss", "precision")
  expect_true(all(is.na(evaluation$std_err[gap])))
  expect_false(any(is.na(evaluation$lower[gap])))

  # And the interval brackets the value on every row that has one.
  has_bounds <- !is.na(evaluation$lower)
  expect_true(all(evaluation$value[has_bounds] >= evaluation$lower[has_bounds]))
  expect_true(all(evaluation$value[has_bounds] <= evaluation$upper[has_bounds]))
})

test_that("threshold.yaml records how far the cutoff itself moves", {
  skip_if_not_installed("ranger")
  skip_if_not_installed("datamatch")

  config <- mock_config()
  config$model$bootstrap <- 300
  config$paths$output_dir <- file.path(tempdir(), "threshold_interval")
  generate_mock_zoop_data(config)
  result <- suppressMessages(run_taupatch(config))

  written <- yaml::read_yaml(file.path(config$paths$output_dir, "threshold.yaml"))

  expect_true(written$classification_threshold_lower <=
                written$classification_threshold)
  expect_true(written$classification_threshold >=
                written$classification_threshold_lower)
  expect_true(written$classification_threshold <=
                written$classification_threshold_upper)
})

test_that("the cutoff interval is omitted rather than faked when off", {
  skip_if_not_installed("ranger")

  config <- mock_config()
  config$model$bootstrap <- FALSE
  model <- fit_patch_model(labeled_mock_data(config), config)

  expect_null(model$classification_threshold_interval)
})
