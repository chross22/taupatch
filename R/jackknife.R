#' Covariate jackknife settings
#'
#' Whether a run tests its covariates before fitting, and what it does with the
#' answer. Off by default: it costs `2 * predictors + 1` cross-validations, which
#' is minutes on a station table and worth paying deliberately rather than on
#' every iteration.
#'
#' ```yaml
#' covariates:
#'   jackknife: true            # or the block below, for the non-defaults
#'   jackknife:
#'     metric: roc_auc          # or: pr_auc
#'     criterion: fold          # or: parametric  (glm and gam only)
#'     alpha: 0.05
#'     adjust: holm             # or: BH, bonferroni, none
#'     drop: false              # DEFAULT: report, never drop on its own
#'     keep: [DEPTH, jday]      # never dropped, whatever the test says
#'     min_predictors: 2        # never drop below this many
#'     workers: true            # true = cores - 1; a count; false = sequential
#' ```
#'
#' @section Dropping is opt-in, and that is deliberate:
#' `drop` defaults to `false`, so the default behaviour is a table and a message.
#' A covariate that fails this test is one the *other covariates already
#' account for* on these stations — which is a statement about collinearity in
#' this sample at least as much as about ecology. Bottom depth and sea surface
#' temperature carry much of the same information on a shelf; the test will
#' happily declare either one redundant depending on which the model reached for
#' first, and dropping it silently would make the map look better while removing
#' the variable a reader would have asked about.
#'
#' `keep` is the escape hatch for exactly that: a covariate that is in the model
#' because the study is about it stays in the model.
#'
#' @param config a config list, as returned by `load_config()`
#' @return `NULL` when off, otherwise a list with `metric`, `criterion`,
#'   `alpha`, `adjust`, `drop`, `keep`, `min_predictors`, and `workers`
#' @examples
#' config <- load_config(
#'   system.file("configs/mock_test.yaml", package = "taupatch")
#' )
#' jackknife_settings(config)                       # NULL: off by default
#'
#' config$covariates$jackknife <- TRUE
#' jackknife_settings(config)                       # drop is FALSE
#'
#' config$covariates$jackknife <- list(drop = TRUE, keep = "jday")
#' jackknife_settings(config)
#' @seealso [jackknife_covariates()], which runs it
#' @export
jackknife_settings <- function(config) {
  spec <- config$covariates$jackknife
  if (is.null(spec) || isFALSE(spec)) return(NULL)
  if (isTRUE(spec)) spec <- list()

  if (!is.list(spec)) {
    stop("covariates.jackknife must be true, false, or a block of settings.",
         call. = FALSE)
  }
  if (isFALSE(spec$enabled)) return(NULL)
  parse_jackknife(spec)
}

#' The jackknife settings a run would use with nothing configured
#'
#' [jackknife_covariates()] can be called on a config with no jackknife block at
#' all — testing covariates is a reasonable thing to do interactively without
#' editing a file for it — and this is what it uses then.
#'
#' @return the same shape [jackknife_settings()] returns
#' @keywords internal
jackknife_defaults <- function() parse_jackknife(list())

#' Validate and fill in one jackknife block
#'
#' @param spec the `covariates.jackknife` block, as a list
#' @return the settings list
#' @keywords internal
parse_jackknife <- function(spec) {
  settings <- list(
    metric = spec$metric %||% "roc_auc",
    criterion = spec$criterion %||% "fold",
    alpha = spec$alpha %||% 0.05,
    adjust = spec$adjust %||% "holm",
    # Never on by accident. A user who wants covariates removed from their own
    # model says so in the config.
    drop = isTRUE(spec$drop),
    keep = as.character(spec$keep %||% character()),
    min_predictors = as.integer(spec$min_predictors %||% 2L),
    workers = spec$workers,
    # Which model type does the testing. Normally the run's own, which is the
    # only sensible default; naming one matters for an ensemble run, where
    # there is no single type to inherit.
    type = spec$type
  )

  if (!(settings$metric %in% c("roc_auc", "pr_auc"))) {
    stop("covariates.jackknife.metric must be 'roc_auc' or 'pr_auc', got '",
         settings$metric, "'.\nBoth are threshold-free, which is what lets ",
         "them be compared fold by fold.", call. = FALSE)
  }
  if (!(settings$criterion %in% c("fold", "parametric"))) {
    stop("covariates.jackknife.criterion must be 'fold' or 'parametric', got '",
         settings$criterion, "'.", call. = FALSE)
  }
  if (!is.numeric(settings$alpha) || settings$alpha <= 0 || settings$alpha >= 1) {
    stop("covariates.jackknife.alpha must be between 0 and 1, got ",
         settings$alpha, ".", call. = FALSE)
  }
  if (!(settings$adjust %in% c(stats::p.adjust.methods))) {
    stop("covariates.jackknife.adjust must be one of: ",
         paste(stats::p.adjust.methods, collapse = ", "), ", got '",
         settings$adjust, "'.", call. = FALSE)
  }
  if (is.na(settings$min_predictors) || settings$min_predictors < 1) {
    stop("covariates.jackknife.min_predictors must be at least 1.", call. = FALSE)
  }
  if (!is.null(settings$type) && !(settings$type %in% names(model_types()))) {
    stop("Unknown covariates.jackknife.type '", settings$type, "'.\nAvailable: ",
         paste(names(model_types()), collapse = ", "), call. = FALSE)
  }
  settings
}

#' Which model type does the jackknifing
#'
#' The run's own type, normally. An ensemble run has no single type, so it takes
#' the first member and says so — a covariate test has to be a test of
#' *something*, and silently picking one of four algorithms would leave a reader
#' of the table with no way to know which.
#'
#' `covariates.jackknife.type` overrides both. A GLM is the type to name there
#' if what is wanted is the classical answer, since it is the one whose test has
#' an exact form.
#'
#' @param config a config list, as returned by `load_config()`
#' @param settings from [jackknife_settings()]
#' @return a model type name
#' @keywords internal
jackknife_type <- function(config, settings) {
  if (!is.null(settings$type)) return(settings$type)

  ensemble <- ensemble_settings(config)
  if (is.null(ensemble)) return(resolve_model_type(config))

  chosen <- ensemble$types[1]
  message("  this run fits an ensemble, so the jackknife tests covariates ",
          "against its first member ('", chosen,
          "'); set covariates.jackknife.type to choose another")
  chosen
}

#' Validate the covariate jackknife block
#'
#' @param config a parsed config list
#' @return `TRUE` invisibly; errors otherwise
#' @keywords internal
validate_jackknife <- function(config) {
  settings <- jackknife_settings(config)
  if (is.null(settings)) return(invisible(TRUE))

  # The fold test needs enough folds for a t with a usable number of degrees of
  # freedom, and the Nadeau-Bengio correction is undefined at one fold.
  folds <- config$model$cv_folds %||% 10
  if (folds < 3) {
    stop("covariates.jackknife needs at least 3 model.cv_folds to have ",
         "anything to test across; got ", folds, ".", call. = FALSE)
  }

  # A parametric criterion on a forest would silently never fire, since there
  # is no such test to report. Said at load rather than after the refits.
  if (identical(settings$criterion, "parametric")) {
    type <- settings$type %||% if (is.null(ensemble_settings(config))) {
      resolve_model_type(config)
    } else {
      ensemble_settings(config)$types[1]
    }
    if (!(type %in% c("glm", "gam"))) {
      stop("covariates.jackknife.criterion is 'parametric', but a ",
           "likelihood-based test only exists for a 'glm' or 'gam'; this ",
           "jackknife would use '", type, "'.\nUse criterion: fold, which is ",
           "defined for every model type, or set covariates.jackknife.type.",
           call. = FALSE)
    }
  }
  invisible(TRUE)
}

#' Test every covariate by leaving it out, in parallel
#'
#' The jackknife of Elith et al. (2011): refit the model without each covariate
#' in turn, and see how much worse it ranks stations. A covariate whose removal
#' costs nothing is one the others already account for. Alongside it goes the
#' other half of the classical jackknife — the model fitted on that covariate
#' *alone* — because the two answer different questions and the pair is what
#' makes the table readable:
#'
#' * **`score_without`** is low when the covariate carries something no other
#'   covariate has. This is its *unique* contribution.
#' * **`score_only`** is high when the covariate carries a lot on its own,
#'   whether or not anything else carries it too.
#'
#' A covariate can score high on one and nothing on the other, and that
#' combination is the informative one: high `score_only` with no unique
#' contribution means the information is real and duplicated, which is a very
#' different thing from a covariate that is simply uninformative.
#'
#' Every refit uses **the same cross-validation folds as the main model**, drawn
#' from `model.seed`, so the comparison is paired fold by fold and none of the
#' difference is the split moving underneath it.
#'
#' @section What "significant" means here:
#' The reported `p_value` is a one-sided test of whether leaving the covariate
#' out makes the model worse, computed from the per-fold differences with the
#' variance correction of Nadeau and Bengio (2003).
#'
#' The correction is the load-bearing part. A plain paired t-test across `k`
#' folds treats the folds as independent, and they are not — any two training
#' sets share most of their rows — so its variance estimate is badly optimistic
#' and it declares far more covariates significant than it should. There is no
#' unbiased estimator of the variance of k-fold cross-validation (Bengio and
#' Grandvalet 2004); the correction inflates the naive variance by
#' `1/k + 1/(k-1)` instead, which is the standard workable answer and roughly
#' halves the t statistic.
#'
#' `p_adjusted` then accounts for having asked the question once per covariate,
#' Holm by default.
#'
#' @section The parametric column:
#' For a GLM and a GAM there is an exact-ish test of the same hypothesis, and it
#' is reported beside the fold test rather than instead of it:
#'
#' * **`glm`** — the drop-in-deviance likelihood ratio test against the nested
#'   model, `parametric_test` reading `LRT`.
#' * **`gam`** — `mgcv`'s approximate p-value for the term, `parametric_test`
#'   reading `gam-approx`. It is approximate by construction: it does not
#'   account for the smoothing parameters having been estimated from the same
#'   data, so it runs anti-conservative (Wood 2017, section 6.12).
#'
#' A forest and a boosted tree have no likelihood, so these columns are `NA`
#' there. That is the whole reason the fold test is the default criterion —
#' it means the same thing for all four model types.
#'
#' @section Rows, not just columns:
#' Every model here is fitted on the rows that are complete across **all**
#' predictors, including the ones being left out. Letting a reduced model pick
#' up the rows its dropped covariate was missing would compare two models on
#' two different datasets, and the reduced one would sometimes win for that
#' reason alone.
#'
#' @param dat labeled modeling data from `label_patch()` with covariates attached
#' @param config a config list, as returned by `load_config()`
#' @param settings from [jackknife_settings()]; defaults are used when the
#'   config has no jackknife block, so this can be called on any config
#' @return a data frame with one row per covariate, ordered by `contribution`,
#'   carrying `variable`, `metric`, `score_full`, `score_without`, `score_only`,
#'   `contribution`, `contribution_se`, `statistic`, `df`, `p_value`,
#'   `p_adjusted`, `parametric_p`, `parametric_test`, `significant`, and
#'   `n_folds`. The full model's score is on it as a `score_full` attribute.
#' @examples
#' \dontrun{
#' config <- load_config("my_run.yaml")
#' dat <- label_patch(attach_covariates(load_zoop_data(config),
#'                                      fetch_covariates(config), config), config)
#' jk <- jackknife_covariates(dat, config)
#' jk[c("variable", "contribution", "p_adjusted", "significant")]
#' }
#' @references
#' Elith J, Phillips SJ, Hastie T, Dudík M, Chee YE, Yates CJ (2011). A
#' statistical explanation of MaxEnt for ecologists. *Diversity and
#' Distributions* **17**(1), 43-57.
#' \doi{10.1111/j.1472-4642.2010.00725.x} — the leave-one-out / only-one pair
#' this reports
#'
#' Nadeau C, Bengio Y (2003). Inference for the generalization error. *Machine
#' Learning* **52**(3), 239-281. \doi{10.1023/A:1024068626366} — the variance
#' correction
#'
#' Bengio Y, Grandvalet Y (2004). No unbiased estimator of the variance of
#' k-fold cross-validation. *Journal of Machine Learning Research* **5**,
#' 1089-1105. <https://jmlr.org/papers/v5/grandvalet04a.html> — why a correction
#' is needed rather than a better estimator
#'
#' Dietterich TG (1998). Approximate statistical tests for comparing supervised
#' classification learning algorithms. *Neural Computation* **10**(7),
#' 1895-1923. \doi{10.1162/089976698300017197} — the inflated Type I error of
#' the uncorrected test
#'
#' Wood SN (2017). *Generalized Additive Models: An Introduction with R*, 2nd
#' edition. Chapman and Hall/CRC. \doi{10.1201/9781315370279} — the GAM term
#' p-values and their caveat
#' @seealso [jackknife_settings()] for the config block, [jackknife_dropped()]
#'   for what `drop` would remove, [permutation_importance()] for the other
#'   answer to "which covariate matters"
#' @export
jackknife_covariates <- function(dat, config, settings = NULL) {
  settings <- settings %||% jackknife_settings(config) %||% jackknife_defaults()

  type <- jackknife_type(config, settings)
  check_model_packages(type)
  # Every fit below builds its specification from the config, so the type the
  # jackknife tests has to be the type the config names.
  config$model$type <- type
  config$model$ensemble <- NULL
  if (length(model_types()[[type]]$tunable) == 0) config$model$tune <- FALSE

  predictors <- predictor_names(dat, config)
  if (length(predictors) < 2) {
    stop("A jackknife needs at least 2 predictors to leave one out of; found ",
         length(predictors), ".", call. = FALSE)
  }

  model_data <- as.data.frame(dat[c(predictors, "patch")])
  model_data <- model_data[stats::complete.cases(model_data), , drop = FALSE]
  if (nrow(model_data) == 0) {
    stop("No rows are complete across every predictor, so there is nothing to ",
         "jackknife.", call. = FALSE)
  }

  # The same folds the main fit will use, so the two are talking about the same
  # splits and the per-fold differences are paired.
  set.seed(config$model$seed)
  folds <- rsample::vfold_cv(model_data, v = config$model$cv_folds,
                             strata = "patch")

  # One task per model to fit: the full one, then each covariate left out, then
  # each covariate on its own. Built as a flat list so the whole lot is spread
  # across workers at once rather than in two waves.
  tasks <- c(
    list(list(kind = "full", variable = NA_character_, vars = predictors)),
    lapply(predictors, function(v) {
      list(kind = "without", variable = v, vars = setdiff(predictors, v))
    }),
    lapply(predictors, function(v) {
      list(kind = "only", variable = v, vars = v)
    })
  )

  workers <- resolve_workers(settings$workers, length(tasks))
  message("  jackknifing ", length(predictors), " covariates: ", length(tasks),
          " cross-validations across ", workers,
          if (workers == 1) " worker" else " workers")

  scores <- taupatch_lapply(tasks, function(task) {
    fold_scores(task$vars, folds, config, type, settings$metric)
  }, workers = workers, seed = config$model$seed)

  full <- scores[[1]]
  without <- scores[seq_along(predictors) + 1L]
  only <- scores[seq_along(predictors) + 1L + length(predictors)]

  parametric <- parametric_tests(model_data, predictors, config, type)

  rows <- lapply(seq_along(predictors), function(i) {
    differences <- full - without[[i]]
    test <- corrected_paired_test(differences)
    data.frame(
      variable = predictors[i],
      metric = settings$metric,
      score_full = mean(full, na.rm = TRUE),
      score_without = mean(without[[i]], na.rm = TRUE),
      score_only = mean(only[[i]], na.rm = TRUE),
      contribution = test$estimate,
      contribution_se = test$std_err,
      statistic = test$statistic,
      df = test$df,
      p_value = test$p_value,
      parametric_p = parametric$p_value[[i]],
      parametric_test = parametric$test,
      n_folds = test$n,
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  out$p_adjusted <- stats::p.adjust(out$p_value, method = settings$adjust)
  criterion <- if (identical(settings$criterion, "parametric")) {
    out$parametric_p
  } else {
    out$p_adjusted
  }
  # NA is not evidence of no effect. A covariate whose test could not be
  # computed counts as contributing, so a failed test can never remove it.
  out$significant <- is.na(criterion) | criterion < settings$alpha

  out <- out[c("variable", "metric", "score_full", "score_without", "score_only",
               "contribution", "contribution_se", "statistic", "df", "p_value",
               "p_adjusted", "parametric_p", "parametric_test", "significant",
               "n_folds")]
  out <- out[order(-out$contribution), ]
  rownames(out) <- NULL
  attr(out, "score_full") <- mean(full, na.rm = TRUE)
  attr(out, "settings") <- settings
  out
}

#' One model's score on every fold
#'
#' Fitted and scored by hand rather than through `tune::fit_resamples()`, for
#' one reason: the per-fold numbers are the whole point here, and they have to
#' come from the *same* `rsample` folds for every covariate subset so the
#' differences pair up. Going through `tune` would mean re-deriving the folds
#' inside each call and getting the pairing only by luck.
#'
#' A fold that will not fit — a subset with one predictor that is constant on
#' that split, say — scores `NA` rather than failing the run, and the test
#' downstream drops it and reports the reduced `n_folds`.
#'
#' @param vars the predictors this model gets
#' @param folds the shared `rsample::vfold_cv()` object
#' @param config a config list, as returned by `load_config()`
#' @param type the model type being fitted
#' @param metric `"roc_auc"` or `"pr_auc"`
#' @return a numeric vector, one score per fold
#' @keywords internal
fold_scores <- function(vars, folds, config, type, metric = "roc_auc") {
  score <- if (identical(metric, "pr_auc")) {
    yardstick::pr_auc_vec
  } else {
    yardstick::roc_auc_vec
  }

  vapply(folds$splits, function(split) {
    train <- rsample::analysis(split)[c(vars, "patch")]
    test <- rsample::assessment(split)[c(vars, "patch")]

    fitted <- tryCatch(
      parsnip::fit(subset_workflow(train, vars, config, type), data = train),
      error = function(e) NULL
    )
    if (is.null(fitted)) return(NA_real_)

    tryCatch({
      probabilities <- stats::predict(fitted, new_data = test, type = "prob")
      score(test$patch, probabilities$.pred_patch)
    }, error = function(e) NA_real_, warning = function(w) NA_real_)
  }, numeric(1))
}

#' The workflow for one covariate subset
#'
#' The same recipe and specification the real fit uses, restricted to a subset
#' of the predictors — so a jackknifed model differs from the full one in
#' exactly the covariate that was removed, and not in how it was preprocessed.
#'
#' @param train the training rows, carrying `vars` and `patch`
#' @param vars the predictors this model gets
#' @param config a config list, as returned by `load_config()`
#' @param type the model type being fitted
#' @return a `workflows::workflow()`, not yet fitted
#' @keywords internal
subset_workflow <- function(train, vars, config, type) {
  wf <- workflows::add_recipe(workflows::workflow(),
                              build_recipe(train, config))
  formula <- model_formula(type, train, vars, config)
  if (is.null(formula)) {
    workflows::add_model(wf, build_model_spec(config))
  } else {
    workflows::add_model(wf, build_model_spec(config), formula = formula)
  }
}

#' A paired test across folds, with the Nadeau-Bengio variance correction
#'
#' The naive paired t-test over `k` cross-validation folds pretends the folds
#' are independent. They share all but one fold's worth of training data, so its
#' variance estimate is far too small and it finds significance everywhere. This
#' inflates the variance by `1/k + 1/(k-1)` — the second term being the ratio of
#' test-set to training-set size in k-fold — which is the standard correction
#' and costs roughly a factor of `sqrt(2)` off the statistic.
#'
#' One-sided, because the hypothesis is directional: the question is whether
#' removing the covariate makes the model *worse*, and a covariate whose removal
#' improves the model has failed the test rather than passed a different one.
#'
#' @param differences per-fold score of the full model minus the reduced one
#' @return a list of `estimate`, `std_err`, `statistic`, `df`, `p_value`, `n`
#' @references
#' Nadeau C, Bengio Y (2003). Inference for the generalization error. *Machine
#' Learning* **52**(3), 239-281. \doi{10.1023/A:1024068626366}
#'
#' Bouckaert RR, Frank E (2004). Evaluating the replicability of significance
#' tests for comparing learning algorithms. *Advances in Knowledge Discovery
#' and Data Mining*, 3-12. \doi{10.1007/978-3-540-24775-3_3} — the correction
#' applied to k-fold specifically
#' @keywords internal
corrected_paired_test <- function(differences) {
  usable <- differences[is.finite(differences)]
  k <- length(usable)
  none <- list(estimate = NA_real_, std_err = NA_real_, statistic = NA_real_,
               df = NA_real_, p_value = NA_real_, n = k)
  if (k < 3) return(none)

  estimate <- mean(usable)
  # 1/k is the naive paired variance; 1/(k-1) is the test-to-train size ratio
  # that k-fold's overlapping training sets add.
  std_err <- sqrt(stats::var(usable) * (1 / k + 1 / (k - 1)))

  if (!is.finite(std_err) || std_err == 0) {
    # Identical on every fold. Either the covariate did exactly nothing, or it
    # did the same thing everywhere - and only the second is evidence.
    return(list(estimate = estimate, std_err = 0,
                statistic = if (estimate > 0) Inf else -Inf, df = k - 1,
                p_value = if (estimate > 0) 0 else 1, n = k))
  }

  statistic <- estimate / std_err
  list(estimate = estimate, std_err = std_err, statistic = statistic,
       df = k - 1,
       p_value = stats::pt(statistic, df = k - 1, lower.tail = FALSE),
       n = k)
}

#' The likelihood-based test, where the model type has one
#'
#' A GLM gets a drop-in-deviance likelihood ratio test against each nested
#' model, which is exact. A GAM gets `mgcv`'s approximate p-value for the term,
#' which is not — it conditions on smoothing parameters estimated from the same
#' data and so runs anti-conservative. A forest and a boosted tree get `NA`,
#' because there is no likelihood to take a ratio of.
#'
#' Fitted on the whole dataset rather than per fold: this is a test about the
#' model, not about its generalization, which is exactly what makes it a
#' different reading from the fold test beside it.
#'
#' @param model_data the complete-case modeling data
#' @param predictors predictor column names
#' @param config a config list, as returned by `load_config()`
#' @param type the model type being fitted
#' @return a list of `p_value` (one per predictor, in order) and `test` (a label)
#' @keywords internal
parametric_tests <- function(model_data, predictors, config, type) {
  none <- list(p_value = rep(NA_real_, length(predictors)),
               test = NA_character_)
  if (!(type %in% c("glm", "gam"))) return(none)

  engine_fit <- function(vars) {
    tryCatch(
      workflows::extract_fit_engine(
        parsnip::fit(subset_workflow(model_data[c(vars, "patch")], vars, config, type),
                     data = model_data)
      ),
      error = function(e) NULL
    )
  }

  full <- engine_fit(predictors)
  if (is.null(full)) return(none)

  if (identical(type, "gam")) {
    return(list(p_value = gam_term_p_values(full, predictors),
                test = "gam-approx"))
  }

  # A GLM's nested comparison, one refit per covariate. Cheap next to the
  # cross-validations that have already run, so it is not worth parallelizing
  # separately.
  p_values <- vapply(predictors, function(v) {
    reduced <- engine_fit(setdiff(predictors, v))
    if (is.null(reduced)) return(NA_real_)

    statistic <- stats::deviance(reduced) - stats::deviance(full)
    df <- reduced$df.residual - full$df.residual
    if (!is.finite(statistic) || !is.finite(df) || df <= 0) return(NA_real_)
    stats::pchisq(statistic, df = df, lower.tail = FALSE)
  }, numeric(1))

  list(p_value = unname(p_values), test = "LRT")
}

#' Pull each predictor's approximate p-value out of a fitted GAM
#'
#' A predictor enters the formula either as a smooth or, when it had too few
#' distinct values for one, as a linear term — see [model_formula()] — so its
#' p-value is in the smooth table for some predictors and the parametric table
#' for others. Both are looked in, keyed on the term name rather than on
#' position.
#'
#' @param fit a fitted `mgcv::gam`
#' @param predictors predictor column names
#' @return a numeric vector of p-values, one per predictor
#' @keywords internal
gam_term_p_values <- function(fit, predictors) {
  summary_gam <- tryCatch(summary(fit), error = function(e) NULL)
  if (is.null(summary_gam)) return(rep(NA_real_, length(predictors)))

  smooth <- summary_gam$s.table
  parametric <- summary_gam$p.table

  lookup <- c(
    if (!is.null(smooth)) stats::setNames(smooth[, ncol(smooth)], rownames(smooth)),
    if (!is.null(parametric)) {
      stats::setNames(parametric[, ncol(parametric)], rownames(parametric))
    }
  )
  if (length(lookup) == 0) return(rep(NA_real_, length(predictors)))

  vapply(predictors, function(v) {
    # Single brackets, not double: a name that is not there gives NA here and
    # an error there, and a predictor that entered linearly is genuinely absent
    # from the smooth table.
    hit <- lookup[paste0("s(", v, ")")]
    if (is.na(hit)) hit <- lookup[v]
    as.numeric(hit)
  }, numeric(1), USE.NAMES = FALSE)
}

#' Which covariates a jackknife would drop
#'
#' The `keep` list and `min_predictors` floor applied to the test result. Split
#' out from the run so a report-only jackknife can still say what dropping
#' *would* have removed, which is the number worth seeing before turning
#' `drop` on.
#'
#' When the floor binds, the covariates kept are the ones that contributed most,
#' so a run that would have dropped everything keeps the best of a bad set
#' rather than an arbitrary one.
#'
#' @param jk the result of [jackknife_covariates()]
#' @param settings from [jackknife_settings()]. Defaults to the settings the
#'   jackknife was actually run under, which it carries on itself — so asking a
#'   result what it would drop needs nothing but the result.
#' @return a character vector of covariate names, possibly empty
#' @examples
#' jk <- data.frame(
#'   variable = c("SST", "SSS", "CHL"),
#'   contribution = c(0.08, 0.001, 0.0005),
#'   significant = c(TRUE, FALSE, FALSE)
#' )
#' settings <- list(keep = character(), min_predictors = 2)
#' jackknife_dropped(jk, settings)      # only the weakest: the floor binds at 2
#'
#' jackknife_dropped(jk, list(keep = "CHL", min_predictors = 1))
#' @seealso [jackknife_covariates()]
#' @export
jackknife_dropped <- function(jk, settings = attr(jk, "settings")) {
  if (is.null(settings)) {
    stop("No jackknife settings given, and `jk` does not carry any. Pass the ",
         "result of jackknife_settings(), or a list with `keep` and ",
         "`min_predictors`.", call. = FALSE)
  }
  keep <- as.character(settings$keep %||% character())
  floor <- as.integer(settings$min_predictors %||% 2L)

  candidates <- setdiff(jk$variable[!jk$significant], keep)
  if (length(candidates) == 0) return(character())

  # Never below the floor. Ordered by contribution so the ones given back are
  # the strongest of those that failed.
  room <- nrow(jk) - floor
  if (room <= 0) return(character())
  if (length(candidates) > room) {
    ranked <- jk$variable[order(jk$contribution)]
    candidates <- intersect(ranked, candidates)[seq_len(room)]
  }
  sort(candidates)
}

#' Say what the jackknife found, in one place
#'
#' A table of fifteen columns is not something a run's log can print, and the
#' one thing a reader needs from it mid-run is which covariates failed and
#' whether anything is about to be removed on the strength of that.
#'
#' @param jk the result of [jackknife_covariates()]
#' @param settings from [jackknife_settings()]
#' @return `NULL`, invisibly
#' @keywords internal
report_jackknife <- function(jk, settings) {
  failed <- jk$variable[!jk$significant]
  if (length(failed) == 0) {
    message("  every covariate contributes at alpha = ", settings$alpha,
            " (", settings$adjust, "-adjusted)")
  } else {
    message("  no detectable contribution at alpha = ", settings$alpha, ": ",
            paste(failed, collapse = ", "))
  }

  would_drop <- jackknife_dropped(jk, settings)
  if (isTRUE(settings$drop)) {
    if (length(would_drop) > 0) {
      message("  covariates.jackknife.drop is on: removing ",
              paste(would_drop, collapse = ", "))
    }
  } else if (length(would_drop) > 0) {
    message("  covariates.jackknife.drop is off, so nothing is removed. ",
            "Setting it would drop: ", paste(would_drop, collapse = ", "))
  }
  invisible(NULL)
}

#' Remove the covariates a jackknife rejected
#'
#' Written into `covariates.exclude`, which is the mechanism that already
#' existed for keeping a fetched covariate out of the model, rather than a
#' second one beside it. So a dropped covariate is still downloaded and still
#' available to anything downstream that wants it — including a derived
#' covariate that needs it as an ingredient — it just stops being a predictor.
#'
#' @param config a config list, as returned by `load_config()`
#' @param dropped covariate names to exclude
#' @return `config`, with `covariates.exclude` extended
#' @keywords internal
apply_jackknife_drop <- function(config, dropped) {
  if (length(dropped) == 0) return(config)
  config$covariates$exclude <- union(config$covariates$exclude %||% character(),
                                      dropped)
  config
}
