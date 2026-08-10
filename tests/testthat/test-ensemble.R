# A member with just enough on it for build_ensemble() to score, weight and
# combine: an evaluation table, held-out predictions carrying their fold, a
# cutoff and an importance table. Cheaper than fitting four real models when
# what is under test is the combining rather than the fitting.
stub_member <- function(score, cutoff = 0.4, seed = 1) {
  set.seed(seed)
  n <- 60
  is_patch <- rep(c(TRUE, FALSE), c(15, 45))[sample.int(n)]
  list(
    evaluation = data.frame(metric = "tss", threshold = cutoff, value = score,
                            stringsAsFactors = FALSE),
    predictions = data.frame(
      .row = seq_len(n),
      id = rep(paste0("Fold", 1:3), length.out = n),
      patch = factor(ifelse(is_patch, "patch", "non_patch"),
                     levels = c("patch", "non_patch")),
      .pred_patch = ifelse(is_patch, stats::runif(n, 0.4, 0.9),
                           stats::runif(n, 0.05, 0.5)),
      stringsAsFactors = FALSE
    ),
    classification_threshold = cutoff,
    importance = tibble::tibble(variable = c("SST", "SSS"),
                                importance = c(0.10, 0.02)),
    predictors = c("SST", "SSS"),
    model_data = data.frame(SST = stats::runif(n), SSS = stats::runif(n)),
    threshold = 1000
  )
}

# The bootstrap is 2000 resamples by default and this fixture has 60 rows; the
# combining is what is under test, not the interval.
stub_config <- function() {
  config <- mock_config()
  config$model$bootstrap <- FALSE
  config
}

test_that("the ensemble is off unless a config asks for it", {
  config <- mock_config()

  expect_null(ensemble_settings(config))

  config$model$type <- "ensemble"
  expect_setequal(ensemble_settings(config)$types, names(model_types()))

  config$model$type <- "rf"
  config$model$ensemble <- list(types = c("rf", "glm"))
  expect_equal(ensemble_settings(config)$types, c("rf", "glm"))

  config$model$ensemble <- FALSE
  expect_null(ensemble_settings(config))
})

test_that("a malformed ensemble block is refused", {
  config <- mock_config()

  config$model$ensemble <- list(types = c("rf", "maxent"))
  expect_error(ensemble_settings(config), "Unknown model.ensemble.types")

  config$model$ensemble <- list(types = "rf")
  expect_error(ensemble_settings(config), "at least 2 model types")

  config$model$ensemble <- list(types = c("rf", "glm"), rule = "vote")
  expect_error(ensemble_settings(config), "rule must be one of")

  config$model$ensemble <- list(types = c("rf", "glm"), weight_by = "aic")
  expect_error(ensemble_settings(config), "weight_by must be one of")

  # An override for a type the ensemble does not fit is a typo, and silently
  # ignoring it means the setting the user wanted never took effect.
  config$model$ensemble <- list(types = c("rf", "glm"),
                                settings = list(gam = list(method = "REML")))
  expect_error(ensemble_settings(config), "overrides for types the ensemble")
})

test_that("fit_patch_model refuses an ensemble type rather than guessing one", {
  config <- mock_config()
  config$model$type <- "ensemble"

  expect_error(resolve_model_type(config), "fit_patch_ensemble")
})

test_that("a member config carries the run's settings with its own type set", {
  config <- mock_config()
  config$model$tune <- TRUE
  settings <- ensemble_settings(within(config, model$type <- "ensemble")) %||%
    list(types = names(model_types()), settings = list(gam = list(method = "REML")))
  settings$settings <- list(gam = list(method = "REML"))

  gam <- member_config(config, "gam", settings)
  expect_equal(gam$model$type, "gam")
  expect_equal(gam$model$method, "REML")
  expect_null(gam$model$ensemble)
  # A GAM has tunable parameters, so a run-level tune survives.
  expect_true(gam$model$tune)

  # A GLM has none, so leaving tune on would make the ensemble refuse to fit
  # the one member that is the honest baseline.
  glm <- member_config(config, "glm", settings)
  expect_false(glm$model$tune)
  expect_true(validate_model(glm))
})

test_that("weights are proportional to score and sum to one", {
  scores <- c(rf = 0.6, brt = 0.4, glm = 0.2)
  weights <- ensemble_weights(scores, c(TRUE, TRUE, TRUE))

  expect_equal(sum(weights), 1)
  expect_equal(unname(weights), c(0.5, 1 / 3, 1 / 6))
  expect_equal(names(weights), names(scores))
})

test_that("a member that did not qualify gets zero weight, not a share", {
  scores <- c(rf = 0.6, brt = 0.4, glm = 0.05)
  weights <- ensemble_weights(scores, c(TRUE, TRUE, FALSE))

  expect_equal(unname(weights[["glm"]]), 0)
  expect_equal(sum(weights), 1)
})

test_that("a member predicting worse than chance cannot be given negative influence", {
  # TSS runs from -1 to 1. A negative weight would make the ensemble
  # deliberately invert that member rather than ignore it.
  scores <- c(rf = 0.6, brt = -0.3)
  weights <- ensemble_weights(scores, c(TRUE, TRUE))

  expect_true(all(weights >= 0))
  expect_equal(sum(weights), 1)
})

test_that("equal weighting ignores the scores", {
  weights <- ensemble_weights(c(rf = 0.9, glm = 0.1), c(TRUE, TRUE),
                              metric = "equal")

  expect_equal(unname(weights), c(0.5, 0.5))
})

test_that("every combination rule lands on the 0-1 scale and means what it says", {
  probabilities <- matrix(c(0.9, 0.1, 0.5,
                            0.7, 0.2, 0.5,
                            0.1, 0.3, 0.5),
                          nrow = 3,
                          dimnames = list(NULL, c("rf", "brt", "glm")))
  weights <- c(rf = 0.5, brt = 0.3, glm = 0.2)
  cutoffs <- c(rf = 0.5, brt = 0.5, glm = 0.5)

  combined <- combine_members(probabilities, weights, cutoffs)

  expect_equal(combined$mean, rowMeans(probabilities))
  expect_equal(combined$weighted_mean, as.numeric(probabilities %*% weights))
  expect_equal(combined$median, apply(probabilities, 1, stats::median))
  # Committee averaging: the fraction of members calling the cell a patch at
  # their own cutoff. Row 1 is (0.9, 0.7, 0.1), so 2 of 3; row 2 is
  # (0.1, 0.2, 0.3), so none; row 3 is (0.5, 0.5, 0.5), so all three.
  expect_equal(combined$committee, c(2 / 3, 0, 1))

  for (rule in ensemble_rules()) {
    expect_true(all(combined[[rule]] >= 0 & combined[[rule]] <= 1), info = rule)
  }
  expect_equal(combined$algorithm_range,
               apply(probabilities, 1, max) - apply(probabilities, 1, min))
})

test_that("each member binarises at its own cutoff for the committee vote", {
  # A shared cutoff would score every member on a threshold that suits whichever
  # happens to be best calibrated.
  probabilities <- matrix(c(0.3, 0.3), nrow = 1,
                          dimnames = list(NULL, c("rf", "glm")))
  weights <- c(rf = 0.5, glm = 0.5)

  expect_equal(combine_members(probabilities, weights,
                               c(rf = 0.2, glm = 0.9))$committee, 0.5)
  expect_equal(combine_members(probabilities, weights,
                               c(rf = 0.2, glm = 0.2))$committee, 1)
})

test_that("a member with no cutoff falls back to 0.5 rather than dropping out", {
  probabilities <- matrix(c(0.6, 0.6), nrow = 1,
                          dimnames = list(NULL, c("rf", "glm")))
  combined <- combine_members(probabilities, c(rf = 0.5, glm = 0.5),
                              c(rf = NA_real_, glm = 0.5))

  expect_equal(combined$committee, 1)
})

test_that("member scores are read at each member's own optimal cutoff", {
  member <- list(evaluation = data.frame(
    metric = c("roc_auc", "tss", "tss"),
    threshold = c(NA_real_, 0.5, 0.18),
    value = c(0.82, 0.11, 0.55),
    stringsAsFactors = FALSE
  ))

  # TSS at 0.5 is the misleading one when the classes are imbalanced, which
  # they are here by construction.
  expect_equal(member_score(member, "tss"), 0.55)
  expect_equal(member_score(member, "roc_auc"), 0.82)
  expect_equal(member_score(member, "equal"), 1)
  expect_true(is.na(member_score(member, "pr_auc")))
})

test_that("an ensemble fits several algorithms and combines them", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 3
  config$model$ensemble <- list(types = c("rf", "glm"), min_score = -1)
  dat <- labeled_mock_data(config)

  ensemble <- suppressMessages(suppressWarnings(fit_patch_ensemble(dat, config)))

  expect_s3_class(ensemble, "taupatch_ensemble")
  expect_setequal(names(ensemble$members), c("rf", "glm"))
  expect_equal(ensemble$type, "ensemble")
  expect_setequal(ensemble$summary$type, c("rf", "glm"))
  expect_equal(sum(ensemble$weights), 1)
  # A drop-in for a single model: the same fields, filled the same way.
  expect_true(all(c("evaluation", "metrics", "importance", "predictors",
                    "classification_threshold") %in% names(ensemble)))
  expect_true(is.numeric(ensemble$classification_threshold))
})

test_that("the ensemble's evaluation is the ensemble's, not the average of its members", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 3
  config$model$ensemble <- list(types = c("rf", "glm"), min_score = -1)
  dat <- labeled_mock_data(config)

  ensemble <- suppressMessages(suppressWarnings(fit_patch_ensemble(dat, config)))

  # It is computed from combined out-of-fold predictions, so it is a real
  # cross-validated number and not a summary of summaries.
  expect_true(all(c(".row", ".pred_patch", "patch") %in%
                    names(ensemble$predictions)))
  expect_equal(nrow(ensemble$predictions),
               nrow(ensemble$members$rf$predictions))

  auc <- evaluation_value(ensemble, "roc_auc")
  expect_equal(auc,
               yardstick::roc_auc_vec(ensemble$predictions$patch,
                                       ensemble$predictions$.pred_patch),
               tolerance = 0.05)
  # Per-fold, so it gets a standard error a pooled number could not have.
  roc_row <- ensemble$metrics[ensemble$metrics$.metric == "roc_auc", ]
  expect_equal(nrow(roc_row), 1)
  expect_true(is.finite(roc_row$std_err))
})

test_that("members are combined on the rows they were all held out of", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 3
  config$model$ensemble <- list(types = c("rf", "glm"), min_score = -1)
  dat <- labeled_mock_data(config)

  ensemble <- suppressMessages(suppressWarnings(fit_patch_ensemble(dat, config)))

  # tune returns folds in its own order, so matching on position rather than
  # on .row would silently pair each station with a different one.
  rf <- ensemble$members$rf$predictions
  aligned <- rf$patch[match(ensemble$predictions$.row, rf$.row)]
  expect_equal(as.character(ensemble$predictions$patch), as.character(aligned))
})

test_that("ensemble importance is weighted and keeps the per-member columns", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 3
  config$model$ensemble <- list(types = c("rf", "glm"), min_score = -1)
  dat <- labeled_mock_data(config)

  ensemble <- suppressMessages(suppressWarnings(fit_patch_ensemble(dat, config)))

  expect_true(all(c("variable", "importance", "rf", "glm") %in%
                    names(ensemble$importance)))
  # A predictor the forest leans on and the GLM ignores is a fact worth keeping,
  # and the weighted average is the one number that hides it.
  weights <- ensemble$weights[c("rf", "glm")]
  expected <- as.numeric(as.matrix(ensemble$importance[c("rf", "glm")]) %*%
                           (weights / sum(weights)))
  expect_equal(ensemble$importance$importance, expected)
})

test_that("an ensemble whose members all score badly is refused, not averaged", {
  members <- list(rf = stub_member(0.05), glm = stub_member(0.02, seed = 2))
  settings <- list(types = c("rf", "glm"), rule = "mean", weight_by = "tss",
                   min_score = 0.4)

  expect_error(build_ensemble(members, stub_config(), settings),
               "No ensemble member reached")
})

test_that("an ensemble left with one qualifying member says so", {
  # Not an error: the map it produces is still the right map for that member.
  # But an object called an ensemble that is one model has to announce itself,
  # or the run reads as four algorithms agreeing.
  members <- list(rf = stub_member(0.6), glm = stub_member(0.1, seed = 2))
  settings <- list(types = c("rf", "glm"), rule = "mean", weight_by = "tss",
                   min_score = 0.4)

  expect_warning(ensemble <- build_ensemble(members, stub_config(), settings),
                 "Only one ensemble member")
  expect_equal(sum(ensemble$summary$qualifies), 1)
  expect_equal(unname(ensemble$weights[["glm"]]), 0)
})

test_that("an ensemble projects and writes a layer per rule and per member", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 3
  config$model$ensemble <- list(types = c("rf", "glm"), min_score = -1,
                                rule = "weighted_mean")
  config$projection$years <- c(2018, 2018)
  config$projection$months <- c(6, 6)
  generate_mock_zoop_data(config)

  result <- suppressMessages(suppressWarnings(run_taupatch(config)))

  expect_s3_class(result$model, "taupatch_ensemble")
  expect_true(file.exists(file.path(config$paths$output_dir,
                                     "ensemble_members.csv")))

  stack <- terra::rast(result$projections$geotiff[1])
  expect_true("suitability" %in% names(stack))
  # Every rule the run did not pick is written beside the one it did, so a
  # committee map can be read off the same file without refitting.
  expect_true(all(c("suitability_mean", "suitability_median",
                    "suitability_committee") %in% names(stack)))
  expect_true("algorithm_sd" %in% names(stack))
  expect_true(all(c("member_rf", "member_glm") %in% names(stack)))

  values <- terra::values(stack[["suitability"]])
  expect_true(all(values >= 0 & values <= 1, na.rm = TRUE))
})

test_that("each member keeps its own effect plots rather than sharing an average", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 3
  config$model$ensemble <- list(types = c("rf", "glm"), min_score = -1)
  generate_mock_zoop_data(config)

  suppressMessages(suppressWarnings(run_taupatch(config, project = FALSE)))

  members <- file.path(config$paths$output_dir, "diagnostics", "members")
  expect_true(dir.exists(file.path(members, "rf")))
  expect_true(dir.exists(file.path(members, "glm")))
  # A GLM has coefficients and a forest does not, which is the reason these are
  # written per member instead of once.
  expect_true(file.exists(file.path(members, "glm", "coefficients.csv")))
})

test_that("an algorithm ensemble and a resample ensemble are different columns", {
  skip_on_cran()
  config <- mock_config()
  config$model$trees <- 50
  config$model$cv_folds <- 3
  config$model$ensemble <- list(types = c("rf", "glm"), min_score = -1)
  config$projection$uncertainty <- TRUE
  config$projection$years <- c(2018, 2018)
  config$projection$months <- c(6, 6)
  generate_mock_zoop_data(config)

  result <- suppressMessages(suppressWarnings(run_taupatch(config)))
  stack <- terra::rast(result$projections$geotiff[1])

  # Both, side by side. They measure different things and a reader must be able
  # to tell which is which.
  expect_true("algorithm_sd" %in% names(stack))
  expect_true("suitability_sd" %in% names(stack))
  expect_true("novelty" %in% names(stack))
})

test_that("printing an ensemble says which members carried it", {
  ensemble <- structure(list(
    rule = "weighted_mean",
    summary = data.frame(type = c("rf", "glm"), score = c(0.6, 0.4),
                         metric = "tss", qualifies = c(TRUE, TRUE),
                         weight = c(0.6, 0.4), stringsAsFactors = FALSE),
    evaluation = data.frame(metric = "roc_auc", threshold = NA_real_,
                            value = 0.83),
    classification_threshold = 0.21
  ), class = "taupatch_ensemble")

  expect_output(print(ensemble), "taupatch ensemble")
  expect_output(print(ensemble), "weighted_mean")
  expect_output(print(ensemble), "0.83")
})
