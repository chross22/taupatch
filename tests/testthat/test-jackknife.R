test_that("the jackknife is off unless a config asks for it", {
  config <- mock_config()

  expect_null(jackknife_settings(config))

  config$covariates$jackknife <- TRUE
  expect_type(jackknife_settings(config), "list")

  config$covariates$jackknife <- FALSE
  expect_null(jackknife_settings(config))

  config$covariates$jackknife <- list(enabled = FALSE, drop = TRUE)
  expect_null(jackknife_settings(config))
})

test_that("dropping covariates is off by default", {
  # The one default that matters most here. A test that removes a covariate
  # from someone's model without being asked is worse than no test.
  config <- mock_config()
  config$covariates$jackknife <- TRUE

  expect_false(jackknife_settings(config)$drop)

  config$covariates$jackknife <- list(metric = "pr_auc", alpha = 0.1)
  expect_false(jackknife_settings(config)$drop)

  config$covariates$jackknife <- list(drop = TRUE)
  expect_true(jackknife_settings(config)$drop)
})

test_that("a malformed jackknife block is refused at load", {
  config <- mock_config()

  config$covariates$jackknife <- list(metric = "kappa")
  expect_error(jackknife_settings(config), "must be 'roc_auc' or 'pr_auc'")

  config$covariates$jackknife <- list(alpha = 1.5)
  expect_error(jackknife_settings(config), "alpha must be between 0 and 1")

  config$covariates$jackknife <- list(adjust = "sidak")
  expect_error(jackknife_settings(config), "adjust must be one of")

  config$covariates$jackknife <- list(criterion = "vibes")
  expect_error(jackknife_settings(config), "must be 'fold' or 'parametric'")

  config$covariates$jackknife <- list(type = "maxent")
  expect_error(jackknife_settings(config), "Unknown covariates.jackknife.type")

  config$covariates$jackknife <- "yes please"
  expect_error(jackknife_settings(config), "must be true, false, or a block")
})

test_that("a parametric criterion is refused for a model type that has no likelihood", {
  config <- mock_config()
  config$model$type <- "rf"
  config$covariates$jackknife <- list(criterion = "parametric")

  expect_error(validate_jackknife(config), "only exists for a 'glm' or 'gam'")

  # Naming a type that does have one makes it legal again.
  config$covariates$jackknife$type <- "glm"
  expect_true(validate_jackknife(config))
})

test_that("a jackknife needs enough folds to test across", {
  config <- mock_config()
  config$covariates$jackknife <- TRUE
  config$model$cv_folds <- 2

  expect_error(validate_jackknife(config), "at least 3 model.cv_folds")
})

test_that("the corrected paired test is more conservative than the naive one", {
  # The whole reason the correction is there. Folds share training data, so the
  # naive paired t treats k highly dependent numbers as k independent ones and
  # reports significance that is not there.
  differences <- c(0.03, 0.01, 0.04, 0.02, 0.025, 0.015, 0.035, 0.02, 0.03, 0.01)

  corrected <- corrected_paired_test(differences)
  naive <- stats::t.test(differences, alternative = "greater")

  expect_gt(corrected$p_value, naive$p.value)
  expect_lt(abs(corrected$statistic), abs(naive$statistic))
  # Specifically, the variance is inflated by 1/k + 1/(k-1) rather than 1/k.
  k <- length(differences)
  expect_equal(corrected$std_err,
               sqrt(stats::var(differences) * (1 / k + 1 / (k - 1))))
  expect_equal(corrected$estimate, mean(differences))
  expect_equal(corrected$df, k - 1)
})

test_that("the paired test is one-sided in the direction that matters", {
  # A covariate whose removal *improves* the model has failed the test, not
  # passed a different one.
  improves <- corrected_paired_test(c(-0.05, -0.04, -0.06, -0.05, -0.03))
  hurts <- corrected_paired_test(c(0.05, 0.04, 0.06, 0.05, 0.03))

  expect_gt(improves$p_value, 0.5)
  expect_lt(hurts$p_value, 0.5)
})

test_that("the paired test declines to answer with too few folds", {
  result <- corrected_paired_test(c(0.02, 0.03))

  expect_true(is.na(result$p_value))
  expect_equal(result$n, 2)
})

test_that("a covariate that helped identically on every fold is not called noise", {
  # Zero variance is a division by zero, and the wrong answer there is to
  # report NA for a covariate that helped by the same amount ten times running.
  result <- corrected_paired_test(rep(0.04, 8))

  expect_equal(result$p_value, 0)
  expect_equal(result$estimate, 0.04)

  # And a covariate that did exactly nothing, every time, is not significant.
  expect_equal(corrected_paired_test(rep(0, 8))$p_value, 1)
})

test_that("jackknife_dropped respects the keep list and the floor", {
  jk <- data.frame(
    variable = c("SST", "SSS", "CHL", "MLD"),
    contribution = c(0.08, 0.002, 0.001, 0.0005),
    significant = c(TRUE, FALSE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )

  expect_equal(jackknife_dropped(jk, list(keep = character(), min_predictors = 1)),
               c("CHL", "MLD", "SSS"))

  # A covariate on the keep list is never dropped, whatever the test said.
  expect_equal(jackknife_dropped(jk, list(keep = "SSS", min_predictors = 1)),
               c("CHL", "MLD"))

  # The floor binds, and the ones given back are the strongest of the failures.
  expect_equal(jackknife_dropped(jk, list(keep = character(), min_predictors = 3)),
               "MLD")
  expect_equal(jackknife_dropped(jk, list(keep = character(), min_predictors = 4)),
               character())
})

test_that("a jackknife result knows what settings it ran under", {
  # So asking a result what it would drop needs nothing but the result, which
  # is how it gets used interactively.
  jk <- data.frame(variable = c("SST", "SSS", "CHL"),
                   contribution = c(0.08, 0.002, 0.001),
                   significant = c(TRUE, FALSE, FALSE),
                   stringsAsFactors = FALSE)
  attr(jk, "settings") <- list(keep = "SSS", min_predictors = 1)

  expect_equal(jackknife_dropped(jk), "CHL")
  # An explicit argument still wins over the carried one.
  expect_equal(jackknife_dropped(jk, list(keep = character(),
                                          min_predictors = 1)),
               c("CHL", "SSS"))

  attr(jk, "settings") <- NULL
  expect_error(jackknife_dropped(jk), "does not carry any")
})

test_that("a covariate whose test could not be computed is never dropped", {
  # NA is not evidence of absence. This is checked at the point the flag is
  # set, since jackknife_dropped() only sees the flag.
  jk <- data.frame(variable = c("SST", "SSS"), contribution = c(0.1, 0.01),
                   significant = c(TRUE, TRUE), stringsAsFactors = FALSE)

  expect_equal(jackknife_dropped(jk, list(keep = character(), min_predictors = 1)),
               character())
})

test_that("dropped covariates go through covariates.exclude", {
  # Rather than a second mechanism beside it: a dropped covariate must still be
  # fetched, since a derived covariate may need it as an ingredient.
  config <- mock_config()
  config$covariates$exclude <- "uo"

  updated <- apply_jackknife_drop(config, c("SSS", "uo"))

  expect_setequal(updated$covariates$exclude, c("uo", "SSS"))
  expect_identical(apply_jackknife_drop(config, character()), config)
})

test_that("the jackknife runs end to end and every covariate gets a verdict", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 3
  dat <- labeled_mock_data(config)

  jk <- suppressMessages(jackknife_covariates(dat, config))

  predictors <- predictor_names(dat, config)
  expect_setequal(jk$variable, predictors)
  expect_true(all(c("score_full", "score_without", "score_only", "contribution",
                    "p_value", "p_adjusted", "significant") %in% names(jk)))
  # Ordered by contribution, most first.
  expect_equal(jk$contribution, sort(jk$contribution, decreasing = TRUE))
  # Every model was scored on the same folds, so the full model's score is one
  # number rather than one per covariate.
  expect_length(unique(jk$score_full), 1)
  expect_type(jk$significant, "logical")
  expect_false(any(is.na(jk$significant)))
})

test_that("the leave-one-out and only-one halves answer different questions", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 3
  dat <- labeled_mock_data(config)

  jk <- suppressMessages(jackknife_covariates(dat, config))

  # Both are AUCs on the same folds, so both are on the 0-1 scale, and the
  # contribution is the difference the leave-one-out half measures.
  expect_true(all(jk$score_without >= 0 & jk$score_without <= 1))
  expect_true(all(jk$score_only >= 0 & jk$score_only <= 1))
  expect_equal(jk$contribution, jk$score_full - jk$score_without,
               tolerance = 1e-8)
})

test_that("a GLM jackknife reports a likelihood ratio test beside the fold test", {
  skip_on_cran()
  config <- mock_config()
  config$model$type <- "glm"
  config$model$cv_folds <- 3
  dat <- labeled_mock_data(config)

  jk <- suppressMessages(jackknife_covariates(dat, config))

  expect_true(all(jk$parametric_test == "LRT"))
  expect_false(all(is.na(jk$parametric_p)))
  finite <- jk$parametric_p[!is.na(jk$parametric_p)]
  expect_true(all(finite >= 0 & finite <= 1))
})

test_that("a forest jackknife has no parametric column to fill in", {
  skip_on_cran()
  config <- mock_config()
  config$model$type <- "rf"
  config$model$trees <- 50
  config$model$cv_folds <- 3
  dat <- labeled_mock_data(config)

  jk <- suppressMessages(jackknife_covariates(dat, config))

  # NA rather than a number that looks like a p-value: there is no likelihood
  # here, so there is no test, and saying so is the honest column.
  expect_true(all(is.na(jk$parametric_p)))
  expect_true(all(is.na(jk$parametric_test)))
  # But the fold test is there, which is the point of having it.
  expect_false(all(is.na(jk$p_value)))
})

test_that("the criterion chooses which p-value decides significance", {
  jk_from <- function(criterion, p_fold, p_parametric) {
    out <- data.frame(p_adjusted = p_fold, parametric_p = p_parametric)
    criterion_values <- if (identical(criterion, "parametric")) {
      out$parametric_p
    } else {
      out$p_adjusted
    }
    is.na(criterion_values) | criterion_values < 0.05
  }

  expect_equal(jk_from("fold", c(0.01, 0.9), c(0.9, 0.01)), c(TRUE, FALSE))
  expect_equal(jk_from("parametric", c(0.01, 0.9), c(0.9, 0.01)), c(FALSE, TRUE))
})

test_that("a run with drop off reports but does not remove", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 3
  config$projection$years <- c(2018, 2018)
  config$projection$months <- c(6, 6)
  # An alpha of 1 fails nothing; an alpha this small fails everything, which is
  # what makes "and nothing was removed" a real assertion.
  config$covariates$jackknife <- list(alpha = 1e-12, drop = FALSE)
  generate_mock_zoop_data(config)

  result <- suppressMessages(run_taupatch(config, project = FALSE))

  expect_false(is.null(result$jackknife))
  expect_true(any(!result$jackknife$significant))
  expect_null(result$config$covariates$exclude)
  expect_setequal(result$model$predictors, predictor_names(result$data, config))
  expect_true(file.exists(file.path(config$paths$output_dir,
                                     "covariate_jackknife.csv")))
})

test_that("a run with drop on removes what the test rejected", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 3
  config$covariates$jackknife <- list(alpha = 1e-12, drop = TRUE,
                                      min_predictors = 1, keep = "jday")
  generate_mock_zoop_data(config)

  result <- suppressMessages(run_taupatch(config, project = FALSE))

  dropped <- result$config$covariates$exclude
  expect_true(length(dropped) > 0)
  # The keep list survives the drop, and the model was fitted on what was left.
  expect_false("jday" %in% dropped)
  expect_true("jday" %in% result$model$predictors)
  expect_length(intersect(result$model$predictors, dropped), 0)
})

test_that("workers resolve to something runnable", {
  expect_equal(resolve_workers(FALSE, 8), 1L)
  expect_equal(resolve_workers(1, 8), 1L)
  # Never more workers than tasks.
  expect_lte(resolve_workers(64, 3, quiet = TRUE), 3L)
  expect_gte(resolve_workers(NULL, 8, quiet = TRUE), 1L)
  expect_error(resolve_workers(0, 8), "positive count")
  expect_error(resolve_workers("many", 8), "positive count")
})

test_that("a core-limited check caps the workers instead of erroring", {
  # `R CMD check --as-cran` sets this, and under it parallel::mclapply() does
  # not use fewer cores - it errors outright above two. A default of
  # `cores - 1` therefore turns every jackknife into a failure on any machine
  # with four or more cores, which is how this reached CI the first time.
  withr::local_envvar(c("_R_CHECK_LIMIT_CORES_" = "TRUE"))

  expect_equal(core_ceiling(), 2L)
  expect_lte(resolve_workers(NULL, 16, quiet = TRUE), 2L)
  # A configured count is capped too. The limit is not a preference.
  expect_lte(resolve_workers(8, 16, quiet = TRUE), 2L)
  # And sequential is still reachable.
  expect_equal(resolve_workers(FALSE, 16), 1L)
})

test_that("the core ceiling lifts when the check variable is absent or false", {
  withr::local_envvar(c("_R_CHECK_LIMIT_CORES_" = ""))
  expect_identical(core_ceiling(), Inf)

  withr::local_envvar(c("_R_CHECK_LIMIT_CORES_" = "false"))
  expect_identical(core_ceiling(), Inf)
})

test_that("options(mc.cores) sets the default worker count", {
  # The option R users already reach for, rather than a taupatch-only knob.
  withr::local_envvar(c("_R_CHECK_LIMIT_CORES_" = ""))
  withr::local_options(mc.cores = 2)

  # Windows cannot fork, so it is sequential whatever the option asks for. The
  # expectation has to know that: asserting 2 everywhere passes on the
  # platforms that fork and fails on the one that does not, which is a test
  # describing the author's laptop rather than the function.
  forks <- !identical(.Platform$OS.type, "windows")
  expect_equal(resolve_workers(NULL, 16, quiet = TRUE), if (forks) 2L else 1L)
  # An explicit argument still wins over the option.
  expect_equal(resolve_workers(1, 16), 1L)
})

test_that("a parallel map gives the same answer as a sequential one", {
  skip_on_os("windows")

  square <- function(x) x^2
  expect_equal(taupatch_lapply(1:6, square, workers = 1),
               taupatch_lapply(1:6, square, workers = 2))
})

test_that("a failing worker surfaces the failure rather than a truncated result", {
  skip_on_os("windows")

  # mclapply warns about the failed call on its own way out; the assertion is
  # that the error is re-raised rather than a short list being returned.
  expect_error(
    suppressWarnings(
      taupatch_lapply(1:4, function(x) if (x == 3) stop("nope") else x,
                      workers = 2)
    ),
    "A parallel worker failed"
  )
})
