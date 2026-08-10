# A run with only what compare_runs() reads: held-out predictions carrying the
# station index, the fold, the truth and the probability. Building these by hand
# is what lets the pairing and the arithmetic be tested without fitting
# anything, and lets a "better" run be better by construction rather than by
# luck.
stub_run <- function(skill = 0.3, n = 200, folds = 5, seed = 1, rows = NULL) {
  set.seed(seed)
  rows <- rows %||% seq_len(n)
  n <- length(rows)
  is_patch <- rep(c(TRUE, FALSE), length.out = n)[order(stats::runif(n))]

  # A larger `skill` separates the classes further, so ROC AUC rises with it.
  probability <- stats::plogis(ifelse(is_patch, skill, -skill) +
                                 stats::rnorm(n, sd = 0.5))
  list(predictions = data.frame(
    .row = rows,
    id = paste0("Fold", rep(seq_len(folds), length.out = n)),
    patch = factor(ifelse(is_patch, "patch", "non_patch"),
                   levels = c("patch", "non_patch")),
    .pred_patch = probability,
    stringsAsFactors = FALSE
  ))
}

test_that("compare_runs refuses what it cannot compare", {
  run <- stub_run()

  expect_error(compare_runs(list(a = run)), "at least 2 fitted runs")
  expect_error(compare_runs(list(run, run)), "Name the runs")
  expect_error(compare_runs(list(a = run, b = run), metric = "tss"),
               "must be 'roc_auc' or 'pr_auc'")
  # A model fitted outside the package has no held-out predictions to read.
  expect_error(compare_runs(list(a = run, b = list(predictions = NULL))),
               "no usable held-out predictions")
})

test_that("a run compared with itself shows no difference", {
  run <- stub_run()

  out <- compare_runs(list(a = run, b = run))

  expect_equal(nrow(out), 1)
  expect_equal(out$difference, 0)
  expect_equal(out$p_value, 1)
  expect_equal(out$reference_score, out$comparison_score)
  expect_equal(out$n_dropped, 0)
})

test_that("a genuinely better run is found to be better", {
  # Better by construction: the same stations, the same folds, a wider
  # separation between the classes.
  worse <- stub_run(skill = 0.2, seed = 3)
  better <- stub_run(skill = 2.0, seed = 3)

  out <- compare_runs(list(worse = worse, better = better))

  expect_gt(out$difference, 0)
  expect_lt(out$p_value, 0.05)
  expect_gt(out$comparison_score, out$reference_score)
  # The interval excludes zero, which is the same statement the p-value makes.
  expect_gt(out$lower, 0)
})

test_that("runs are paired on the station index, not on row order", {
  # tune returns folds in its own order, and two runs need not agree on it.
  # Pairing by position would silently compare station i of one run with a
  # different station of the other.
  run <- stub_run(skill = 1.2, seed = 7)
  shuffled <- run
  shuffled$predictions <- run$predictions[order(stats::runif(nrow(run$predictions))), ]

  out <- compare_runs(list(a = run, b = shuffled))

  expect_equal(out$difference, 0)
  expect_equal(out$reference_score, out$comparison_score)
})

test_that("runs covering different stations are intersected, loudly", {
  # Different covariates drop different stations to missingness. Comparing on
  # what they share is right; doing it silently is not.
  full <- stub_run(n = 200, seed = 11, rows = 1:200)
  partial <- stub_run(n = 160, seed = 11, rows = 1:160)

  expect_warning(out <- compare_runs(list(full = full, partial = partial)),
                 "do not cover the same stations")
  expect_equal(out$n_stations, 160)
  expect_equal(out$n_dropped, 40)
})

test_that("two runs sharing almost nothing are refused rather than compared", {
  a <- stub_run(n = 100, rows = 1:100)
  b <- stub_run(n = 100, rows = 500:599)

  expect_error(suppressWarnings(compare_runs(list(a = a, b = b))),
               "share 0 stations")
})

test_that("every run after the first is compared against the first", {
  runs <- list(ref = stub_run(seed = 2), one = stub_run(seed = 2),
               two = stub_run(seed = 2))

  out <- compare_runs(runs)

  expect_equal(nrow(out), 2)
  expect_equal(out$comparison, c("one", "two"))
  expect_true(all(out$reference == "ref"))
})

test_that("the minimum detectable difference behaves like one", {
  # Bigger when the folds disagree more, smaller with more folds, and larger
  # for more power - each of which is the direction that makes it usable.
  expect_gt(minimum_detectable(0.04, df = 4), minimum_detectable(0.02, df = 4))
  expect_gt(minimum_detectable(0.03, df = 2), minimum_detectable(0.03, df = 20))
  expect_gt(minimum_detectable(0.03, df = 9, power = 0.9),
            minimum_detectable(0.03, df = 9, power = 0.8))

  # The formula it claims to be.
  se <- 0.03; df <- 9
  expect_equal(minimum_detectable(se, df, level = 0.95, power = 0.8),
               se * (stats::qt(0.975, df) + stats::qt(0.8, df)))

  expect_true(is.na(minimum_detectable(NA_real_, 4)))
  expect_true(is.na(minimum_detectable(0.03, NA_real_)))
})

test_that("power rises with the difference and falls with the noise", {
  expect_gt(achieved_power(0.10, 0.02, df = 9), achieved_power(0.02, 0.02, df = 9))
  expect_gt(achieved_power(0.05, 0.01, df = 9), achieved_power(0.05, 0.05, df = 9))
  expect_true(all(achieved_power(c(0, 0.5), 0.02, df = 9) %in% c(0, 1) |
                    (achieved_power(c(0, 0.5), 0.02, df = 9) >= 0 &
                       achieved_power(c(0, 0.5), 0.02, df = 9) <= 1)))

  # At exactly the minimum detectable difference, power is the power it was
  # solved for. The two functions are inverses and must agree.
  se <- 0.03; df <- 9
  mde <- minimum_detectable(se, df, level = 0.95, power = 0.8)
  expect_equal(achieved_power(mde, se, df, level = 0.95), 0.8, tolerance = 0.02)
})

test_that("the paired test is two-sided when asked", {
  differences <- c(0.03, 0.01, 0.04, 0.02, 0.025)

  one <- corrected_paired_test(differences)
  two <- corrected_paired_test(differences, alternative = "two.sided")

  expect_equal(two$p_value, 2 * one$p_value)
  expect_equal(two$estimate, one$estimate)
  # A difference in the other direction is a finding for two-sided and not for
  # one-sided, which is the whole reason compare_runs() asks for it.
  flipped <- corrected_paired_test(-differences, alternative = "two.sided")
  expect_equal(flipped$p_value, two$p_value)
  expect_gt(corrected_paired_test(-differences)$p_value, 0.5)
})

test_that("power_curve refuses what it cannot trace", {
  config <- mock_config()

  expect_error(power_curve(data.frame(), list(a = config)), "at least 2 configs")
  expect_error(power_curve(data.frame(), list(config, config)),
               "Name the configs")
})

test_that("power_curve traces power rising with the number of stations", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 5
  dat <- labeled_mock_data(config)

  # A covariate-starved run against the full one, so there is a real difference
  # for the curve to have power against.
  starved <- config
  starved$covariates$exclude <- c("SST", "SSS")

  curve <- suppressMessages(
    power_curve(dat, list(full = config, starved = starved),
                fractions = c(0.25, 1), replicates = 2, workers = 1)
  )

  expect_equal(nrow(curve), 2)
  expect_true(all(c("fraction", "n_stations", "power", "detectable",
                    "difference", "std_err") %in% names(curve)))
  # More stations, more power and a smaller detectable difference. This is the
  # shape the whole function exists to produce.
  expect_gt(curve$n_stations[2], curve$n_stations[1])
  expect_gte(curve$power[2], curve$power[1])
  expect_lt(curve$detectable[2], curve$detectable[1])
  expect_true(all(curve$power >= 0 & curve$power <= 1))
  # The starved run is worse, so the difference is negative throughout.
  expect_true(all(curve$difference < 0))
  expect_true(is.numeric(attr(curve, "difference")))
})

test_that("a power curve is reproducible", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 5
  dat <- labeled_mock_data(config)
  starved <- config
  starved$covariates$exclude <- "SST"

  runs <- list(full = config, starved = starved)
  once <- suppressMessages(power_curve(dat, runs, fractions = 0.5,
                                        replicates = 2, workers = 1))
  twice <- suppressMessages(power_curve(dat, runs, fractions = 0.5,
                                         replicates = 2, workers = 1))

  # Seeded per point rather than per call, so the answer does not depend on how
  # the tasks happened to be spread across workers.
  expect_equal(once$difference, twice$difference)
  expect_equal(once$std_err, twice$std_err)
})
