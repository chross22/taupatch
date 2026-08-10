#' Multi-algorithm ensemble settings
#'
#' Which model types a run fits and how their projections are combined. This is
#' `BIOMOD_EnsembleModeling()` from the pipeline this package replaces: several
#' algorithms on the same data, filtered on how well they did, then averaged.
#'
#' ```yaml
#' model:
#'   type: ensemble             # or set the block below and leave type alone
#'   ensemble:
#'     types: [rf, brt, glm, gam]
#'     rule: weighted_mean      # or: mean, median, committee
#'     weight_by: tss           # or: roc_auc, pr_auc, equal
#'     min_score: 0.4           # members scoring below this are excluded
#'     workers: true            # true = cores - 1; a count; false = sequential
#'     settings:                # per-member overrides of the model block
#'       gam:
#'         method: REML
#'       brt:
#'         learn_rate: 0.01
#' ```
#'
#' @section Two different things called an ensemble:
#' This one combines over **algorithms**, and its spread is disagreement about
#' the shape of the relationship — a forest and a logistic regression looking at
#' the same shelf and drawing different maps.
#'
#' `projection.uncertainty` (see [uncertainty_settings()]) combines over
#' **resamples of the data** within one algorithm, and its spread is how much
#' the fit moves when the stations move.
#'
#' They are independent and can both be on. When they are, each member carries
#' its own resample interval and the ensemble reports algorithm disagreement on
#' top of it, in separate columns — `algorithm_sd` against `suitability_sd`.
#'
#' @section Why filter members at all:
#' An ensemble that averages in a model which cannot separate the classes moves
#' the answer toward noise. `min_score` is biomod2's `metric.select.thresh`
#' under a plainer name, and 0.4 on TSS is a low bar deliberately: it is there
#' to catch a member that failed to fit anything, not to tune the ensemble by
#' selecting its best members on their own evaluation scores, which would be
#' selection on the same numbers used to report it.
#'
#' @param config a config list, as returned by `load_config()`
#' @return `NULL` when off, otherwise a list with `types`, `rule`, `weight_by`,
#'   `min_score`, `workers`, and `settings`
#' @examples
#' config <- load_config(
#'   system.file("configs/mock_test.yaml", package = "taupatch")
#' )
#' ensemble_settings(config)                        # NULL: off by default
#'
#' config$model$type <- "ensemble"
#' ensemble_settings(config)$types
#'
#' config$model$ensemble <- list(types = c("rf", "glm"), rule = "median")
#' ensemble_settings(config)
#' @seealso [fit_patch_ensemble()], which runs it, and [uncertainty_settings()]
#'   for the other kind of ensemble
#' @export
ensemble_settings <- function(config) {
  spec <- config$model$ensemble
  asked <- identical(config$model$type, "ensemble")

  if (is.null(spec) && !asked) return(NULL)
  if (isFALSE(spec)) return(NULL)
  if (is.null(spec) || isTRUE(spec)) spec <- list()
  if (!is.list(spec)) {
    stop("model.ensemble must be true, false, or a block of settings.",
         call. = FALSE)
  }
  if (isFALSE(spec$enabled)) return(NULL)

  settings <- list(
    types = as.character(spec$types %||% names(model_types())),
    rule = spec$rule %||% "weighted_mean",
    weight_by = spec$weight_by %||% "tss",
    min_score = spec$min_score %||% 0.4,
    workers = spec$workers,
    settings = spec$settings %||% list()
  )

  unknown <- setdiff(settings$types, names(model_types()))
  if (length(unknown) > 0) {
    stop("Unknown model.ensemble.types: ", paste(unknown, collapse = ", "),
         "\nAvailable: ", paste(names(model_types()), collapse = ", "),
         call. = FALSE)
  }
  if (length(settings$types) < 2) {
    stop("model.ensemble.types needs at least 2 model types to combine; got ",
         length(settings$types),
         ".\nFor a single type, set model.type to it and leave the ensemble off.",
         call. = FALSE)
  }
  if (!(settings$rule %in% ensemble_rules())) {
    stop("model.ensemble.rule must be one of: ",
         paste(ensemble_rules(), collapse = ", "), ", got '", settings$rule,
         "'.", call. = FALSE)
  }
  if (!(settings$weight_by %in% c("tss", "roc_auc", "pr_auc", "equal"))) {
    stop("model.ensemble.weight_by must be one of: tss, roc_auc, pr_auc, ",
         "equal; got '", settings$weight_by, "'.", call. = FALSE)
  }
  unnamed <- setdiff(names(settings$settings), settings$types)
  if (length(unnamed) > 0) {
    stop("model.ensemble.settings has overrides for types the ensemble does ",
         "not fit: ", paste(unnamed, collapse = ", "),
         "\nFitting: ", paste(settings$types, collapse = ", "), call. = FALSE)
  }
  settings
}

#' Ways an ensemble can combine its members
#'
#' `mean` and `weighted_mean` average the probabilities, the second in
#' proportion to how well each member scored. `median` averages them robustly,
#' which is the one to reach for when a single member is capable of going badly
#' wrong somewhere on the grid — a boosted tree extrapolating, usually — since
#' a mean lets that member drag a cell and a median does not.
#'
#' `committee` is different in kind, and is biomod2's committee averaging: each
#' member binarises its own prediction at its own TSS-optimal cutoff, and the
#' cell gets the fraction of members that called it a patch. So it is already on
#' a 0-to-1 scale and reads directly as agreement — 0.75 means three of four
#' algorithms say patch — but it throws away how *confident* each member was.
#'
#' Every rule is computed and written on every run. `model.ensemble.rule` picks
#' which one is the `suitability` layer, and the others go beside it, because
#' the disagreement between rules is itself worth looking at and recomputing
#' them means refitting.
#'
#' @return character vector of rule names
#' @examples
#' ensemble_rules()
#' @references
#' Araújo MB, New M (2007). Ensemble forecasting of species distributions.
#' *Trends in Ecology & Evolution* **22**(1), 42-47.
#' \doi{10.1016/j.tree.2006.09.010} — why an ensemble of algorithms rather than
#' a chosen best one
#'
#' Marmion M, Parviainen M, Luoto M, Heikkinen RK, Thuiller W (2009). Evaluation
#' of consensus methods in predictive species distribution modelling.
#' *Diversity and Distributions* **15**(1), 59-69.
#' \doi{10.1111/j.1472-4642.2008.00491.x} — the rules compared against each
#' other
#' @export
ensemble_rules <- function() {
  c("mean", "weighted_mean", "median", "committee")
}

#' Fit an ensemble of model types on the same data
#'
#' Fits every type in `model.ensemble.types` on the same stations, the same
#' predictors and the same cross-validation folds, then combines them. The
#' result is a drop-in for a [fit_patch_model()] object: it carries an
#' `evaluation` table, a `classification_threshold`, an `importance` table and a
#' set of `predictors`, and [project_patch_model()] will project it.
#'
#' @section Why an ensemble at all:
#' The four types disagree in ways that are informative rather than incidental.
#' A random forest and a GLM that rank the same stations mean the relationships
#' are close to monotonic; a sharp disagreement means either a genuine
#' non-linearity or a forest fitting noise, and there is no way to tell which
#' from one model. Averaging them is the practical answer to not knowing which
#' is right, and the `algorithm_sd` surface a projection then carries is the map
#' of where that choice actually mattered.
#'
#' @section How the ensemble gets an honest evaluation:
#' Every member is fitted on the same folds, drawn from the same `model.seed`,
#' so the held-out predictions line up row for row. The ensemble's own
#' out-of-fold predictions are therefore built by combining members on the rows
#' none of them saw, and the reported evaluation, the TSS-optimal cutoff and its
#' bootstrap interval all come from those — the same functions, on the same
#' footing, as a single model's.
#'
#' This matters because the obvious alternative is wrong. Averaging the members'
#' evaluation scores would report the ensemble as the average of its parts,
#' which is not what an ensemble does: combining uncorrelated members usually
#' beats all of them, and combining correlated ones does not, and only a
#' cross-validated ensemble prediction can tell those apart.
#'
#' @section A member that fails:
#' A type whose package is not installed, or that will not fit these data, is
#' dropped with a warning rather than failing the run — an ensemble of three is
#' still an ensemble. Two members is the floor; below that the run stops, since
#' one algorithm averaged with nothing is a single model wearing a different
#' object.
#'
#' @param dat labeled modeling data from `label_patch()` with covariates attached
#' @param config a config list, as returned by `load_config()`
#' @param settings from [ensemble_settings()]
#' @return an object of class `taupatch_ensemble`: a list with `members` (the
#'   per-type [fit_patch_model()] results), `summary` (one row per type, with
#'   its score, weight and whether it qualified), `predictions` (combined
#'   out-of-fold), `evaluation`, `classification_threshold`,
#'   `classification_threshold_interval`, `importance` (weighted across
#'   members), `metrics`, `rule`, `predictors`, `model_data`, `threshold`, and
#'   `type`, which is `"ensemble"`
#' @examples
#' \dontrun{
#' config <- load_config("my_run.yaml")
#' config$model$type <- "ensemble"
#' ensemble <- fit_patch_ensemble(dat, config)
#' ensemble$summary
#' ensemble$evaluation
#' }
#' @references
#' Araújo MB, New M (2007). Ensemble forecasting of species distributions.
#' *Trends in Ecology & Evolution* **22**(1), 42-47.
#' \doi{10.1016/j.tree.2006.09.010}
#'
#' Thuiller W, Lafourcade B, Engler R, Araújo MB (2009). BIOMOD - a platform for
#' ensemble forecasting of species distributions. *Ecography* **32**(3),
#' 369-373. \doi{10.1111/j.1600-0587.2008.05742.x} — what this replaces
#' @seealso [ensemble_settings()] for the config block, [ensemble_rules()] for
#'   the combination rules, [fit_patch_model()] for a single member
#' @export
fit_patch_ensemble <- function(dat, config, settings = ensemble_settings(config)) {
  settings <- settings %||% ensemble_settings(config)
  if (is.null(settings)) {
    stop("No ensemble is configured. Set model.type to 'ensemble', or pass ",
         "settings built by ensemble_settings().", call. = FALSE)
  }

  available <- Filter(function(type) {
    installed <- tryCatch({ check_model_packages(type); TRUE },
                          error = function(e) FALSE)
    if (!installed) {
      warning("Ensemble member '", type, "' needs the '",
              model_types()[[type]]$package, "' package, which is not ",
              "installed. Skipping it.", call. = FALSE)
    }
    installed
  }, settings$types)

  if (length(available) < 2) {
    stop("An ensemble needs at least 2 fittable member types; ",
         length(available), " of ", length(settings$types),
         " are available.\nInstall the missing packages, or name types that ",
         "are installed in model.ensemble.types.", call. = FALSE)
  }

  workers <- resolve_workers(settings$workers, length(available))
  message("  fitting ", length(available), " ensemble members (",
          paste(available, collapse = ", "), ") across ", workers,
          if (workers == 1) " worker" else " workers")

  fits <- taupatch_lapply(available, function(type) {
    tryCatch(fit_patch_model(dat, member_config(config, type, settings)),
             error = function(e) {
               structure(list(type = type, message = conditionMessage(e)),
                         class = "taupatch_member_error")
             })
  }, workers = workers, seed = config$model$seed)
  names(fits) <- available

  broken <- vapply(fits, inherits, logical(1), "taupatch_member_error")
  for (type in available[broken]) {
    warning("Ensemble member '", type, "' failed to fit and was dropped: ",
            fits[[type]]$message, call. = FALSE)
  }
  members <- fits[!broken]
  if (length(members) < 2) {
    stop("Only ", length(members), " ensemble member(s) fitted successfully, ",
         "which is not an ensemble. See the warnings above for why the rest ",
         "failed.", call. = FALSE)
  }

  build_ensemble(members, config, settings)
}

#' Assemble the fitted members into an ensemble
#'
#' Split from [fit_patch_ensemble()] so the scoring, weighting and combining can
#' be tested on members built any way at all, including hand-made ones.
#'
#' @param members a named list of [fit_patch_model()] results
#' @param config a config list, as returned by `load_config()`
#' @param settings from [ensemble_settings()]
#' @return a `taupatch_ensemble`
#' @keywords internal
build_ensemble <- function(members, config, settings) {
  scores <- vapply(members, member_score, numeric(1), metric = settings$weight_by)

  qualifies <- !is.na(scores) & scores >= settings$min_score
  if (!any(qualifies)) {
    stop("No ensemble member reached model.ensemble.min_score (",
         settings$min_score, ") on ", settings$weight_by, ". Best was ",
         signif(max(scores, na.rm = TRUE), 3),
         ".\nLower min_score, or fix why every algorithm is doing this badly.",
         call. = FALSE)
  }
  if (sum(qualifies) < 2) {
    # One qualifying member is a single model, and averaging it with nothing
    # would report an ensemble that is not one. Kept as a warning rather than
    # an error because the map it produces is still the right map.
    warning("Only one ensemble member reached min_score (", settings$min_score,
            "); the combined surface is that member alone.", call. = FALSE)
  }

  weights <- ensemble_weights(scores, qualifies, settings$weight_by)
  summary <- data.frame(
    type = names(members),
    label = vapply(names(members), function(t) model_types()[[t]]$label,
                   character(1)),
    score = unname(scores),
    metric = settings$weight_by,
    cutoff = vapply(members, function(m) m$classification_threshold %||% NA_real_,
                    numeric(1)),
    qualifies = unname(qualifies),
    weight = unname(weights),
    stringsAsFactors = FALSE
  )
  summary <- summary[order(-summary$score), ]
  rownames(summary) <- NULL

  keep <- names(members)[qualifies]
  predictions <- ensemble_oof_predictions(members[keep], weights[keep],
                                          settings$rule)
  cutoff <- optimal_threshold(predictions)
  bounds <- bootstrap_evaluation(predictions, cutoff,
                                 times = bootstrap_times(config),
                                 seed = config$model$seed)

  first <- members[[keep[1]]]
  cv_metrics <- ensemble_cv_metrics(predictions)
  structure(list(
    members = members,
    summary = summary,
    weights = weights,
    rule = settings$rule,
    settings = settings,
    predictions = predictions,
    # Built from out-of-fold ensemble predictions by the same functions a single
    # model uses, so an ensemble's evals.csv and a member's mean the same thing
    # and can be read against each other.
    evaluation = evaluation_table(predictions, cv_metrics, cutoff, bounds),
    metrics = cv_metrics,
    member_metrics = member_metrics(members),
    classification_threshold = cutoff,
    classification_threshold_interval = threshold_interval(bounds),
    importance = ensemble_importance(members[keep], weights[keep]),
    # The union rather than the first member's, so a grid cell is only predicted
    # where every member has what it needs.
    predictors = Reduce(union, lapply(members[keep], function(m) m$predictors)),
    model_data = first$model_data,
    threshold = first$threshold,
    type = "ensemble",
    # No single workflow to save. Named rather than absent so anything reaching
    # for it gets a clear NULL instead of a partial match onto something else.
    workflow = NULL
  ), class = "taupatch_ensemble")
}

#' One member's config
#'
#' The run's config with the member's type set, and any per-type overrides from
#' `model.ensemble.settings` merged into the model block. The uncertainty and
#' jackknife blocks are left alone, so a member inherits them exactly.
#'
#' @param config a config list, as returned by `load_config()`
#' @param type the member's model type
#' @param settings from [ensemble_settings()]
#' @return a config list for that member
#' @keywords internal
member_config <- function(config, type, settings) {
  config$model$type <- type
  # Tuning is per-type: a GLM has nothing to tune, and leaving a run-level
  # `tune: true` in place would make the ensemble refuse to fit the one member
  # that is the honest baseline.
  if (length(model_types()[[type]]$tunable) == 0) config$model$tune <- FALSE

  override <- settings$settings[[type]]
  if (!is.null(override)) config$model <- modifyList(config$model, override)
  # A member never fits an ensemble of its own.
  config$model$ensemble <- NULL
  config
}

#' One member's score, on the metric the weights use
#'
#' Read out of the member's own evaluation table rather than recomputed, so the
#' number that decides a member's weight is the number reported for it. The
#' threshold-dependent metrics are taken at the member's own TSS-optimal cutoff,
#' which is the only fair comparison — reading TSS at 0.5 would score every
#' member on a cutoff that suits none of them.
#'
#' @param member a [fit_patch_model()] result
#' @param metric `"tss"`, `"roc_auc"`, `"pr_auc"`, or `"equal"`
#' @return the score, or `NA_real_`
#' @keywords internal
member_score <- function(member, metric = "tss") {
  if (identical(metric, "equal")) return(1)

  table <- member$evaluation
  if (is.null(table)) return(NA_real_)

  rows <- if (metric %in% c("roc_auc", "pr_auc")) {
    table[table$metric == metric & is.na(table$threshold), ]
  } else {
    at_optimal <- !is.na(table$threshold) & table$threshold != 0.5
    table[table$metric == metric & at_optimal, ]
  }
  if (nrow(rows) != 1) return(NA_real_)
  rows$value
}

#' Member weights from member scores
#'
#' Proportional to the score, over the qualifying members only, and summing to
#' one. A non-qualifying member's weight is zero rather than absent, so the
#' summary table shows what it would have been given.
#'
#' TSS runs from -1 to 1 and a negative score is a member predicting worse than
#' chance, so weights are floored at zero — a member cannot be given negative
#' influence, which would make the ensemble deliberately invert it.
#'
#' @param scores one score per member
#' @param qualifies which members cleared `min_score`
#' @param metric which metric the scores are on
#' @return a numeric vector of weights, summing to 1
#' @keywords internal
ensemble_weights <- function(scores, qualifies, metric = "tss") {
  weights <- rep(0, length(scores))
  names(weights) <- names(scores)

  usable <- qualifies & !is.na(scores)
  if (!any(usable)) return(weights)

  if (identical(metric, "equal")) {
    weights[usable] <- 1 / sum(usable)
    return(weights)
  }

  raw <- pmax(scores[usable], 0)
  # Every qualifying member scored exactly zero: there is nothing to weight by,
  # so weight them alike rather than dividing by zero.
  weights[usable] <- if (sum(raw) > 0) raw / sum(raw) else 1 / sum(usable)
  weights
}

#' Combine the members' out-of-fold predictions
#'
#' Every member was cross-validated on the same folds from the same seed, so
#' their held-out predictions cover the same rows and can be combined row by
#' row. Matched on `.row` rather than on position, since `tune` returns folds in
#' its own order and two members need not agree on it.
#'
#' @param members the qualifying [fit_patch_model()] results
#' @param weights their weights
#' @param rule one of [ensemble_rules()]
#' @return a data frame of `.row`, `patch` and `.pred_patch`, in the shape the
#'   evaluation functions expect
#' @keywords internal
ensemble_oof_predictions <- function(members, weights, rule = "weighted_mean") {
  usable <- Filter(function(m) {
    !is.null(m$predictions) && all(c(".row", ".pred_patch") %in% names(m$predictions))
  }, members)
  if (length(usable) == 0) return(NULL)

  rows <- Reduce(intersect, lapply(usable, function(m) m$predictions$.row))
  if (length(rows) == 0) return(NULL)

  probabilities <- vapply(usable, function(m) {
    m$predictions$.pred_patch[match(rows, m$predictions$.row)]
  }, numeric(length(rows)))
  probabilities <- matrix(probabilities, nrow = length(rows),
                          dimnames = list(NULL, names(usable)))

  cutoffs <- vapply(usable, function(m) m$classification_threshold %||% NA_real_,
                    numeric(1))
  combined <- combine_members(probabilities, weights[names(usable)], cutoffs)

  first <- usable[[1]]$predictions
  at <- match(rows, first$.row)
  out <- data.frame(
    .row = rows,
    patch = first$patch[at],
    .pred_patch = combined[[rule]],
    stringsAsFactors = FALSE
  )
  # The fold each row was held out of, carried through so the ensemble can have
  # a per-fold standard error like a single model does rather than only a
  # pooled number.
  if ("id" %in% names(first)) out$id <- first$id[at]
  out
}

#' Cross-validated metrics for the combined ensemble
#'
#' The ensemble's own held-out predictions, scored per fold and summarised in
#' the shape `tune::collect_metrics()` returns — so everything downstream that
#' reads a metrics table reads this one without knowing an ensemble produced it.
#'
#' Computed on the ensemble rather than averaged over members, because those are
#' different numbers and only the first is the ensemble's performance: combining
#' members that make different mistakes beats every one of them, and combining
#' members that make the same mistakes does not.
#'
#' The threshold-dependent rows are at the default 0.5 cutoff, which is what the
#' equivalent rows mean for a single model. [evaluation_table()] restates them at
#' the TSS-optimal cutoff alongside.
#'
#' @param predictions the combined out-of-fold predictions
#' @return a data frame of `.metric`, `.estimator`, `mean`, `n`, `std_err`, with
#'   a `tss` row; `NULL` when the folds are not recoverable
#' @keywords internal
ensemble_cv_metrics <- function(predictions) {
  if (is.null(predictions) || !("id" %in% names(predictions))) return(NULL)

  folds <- split(seq_len(nrow(predictions)), predictions$id)
  per_fold <- function(fn) {
    vapply(folds, function(rows) {
      truth <- predictions$patch[rows]
      probability <- predictions$.pred_patch[rows]
      if (length(unique(truth)) < 2) return(NA_real_)
      tryCatch(fn(truth, probability), error = function(e) NA_real_,
               warning = function(w) NA_real_)
    }, numeric(1))
  }

  hard <- function(truth, probability) {
    factor(ifelse(probability >= 0.5, "patch", "non_patch"),
           levels = levels(truth))
  }

  values <- list(
    roc_auc = per_fold(yardstick::roc_auc_vec),
    kap = per_fold(function(t, p) yardstick::kap_vec(t, hard(t, p))),
    sens = per_fold(function(t, p) yardstick::sens_vec(t, hard(t, p))),
    spec = per_fold(function(t, p) yardstick::spec_vec(t, hard(t, p)))
  )

  out <- do.call(rbind, lapply(names(values), function(metric) {
    scores <- values[[metric]][is.finite(values[[metric]])]
    data.frame(
      .metric = metric, .estimator = "binary",
      mean = if (length(scores) > 0) mean(scores) else NA_real_,
      n = length(scores),
      std_err = if (length(scores) > 1) {
        stats::sd(scores) / sqrt(length(scores))
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  }))
  add_tss(out)
}

#' Apply every combination rule to a matrix of member predictions
#'
#' All four rules at once, because they cost nothing next to the predictions
#' they are computed from and a projection writes all of them. The spread
#' columns come out of the same matrix.
#'
#' @param probabilities rows by members
#' @param weights one per member, in the same column order
#' @param cutoffs each member's own TSS-optimal cutoff, for `committee`
#' @return a named list: one entry per rule, plus `algorithm_sd` and
#'   `algorithm_range`
#' @keywords internal
combine_members <- function(probabilities, weights, cutoffs) {
  weights <- weights[colnames(probabilities)]
  weights[is.na(weights)] <- 0
  # An all-zero weight vector would make the weighted mean NaN everywhere.
  if (sum(weights) == 0) weights <- rep(1 / ncol(probabilities),
                                        ncol(probabilities))
  weights <- weights / sum(weights)

  # Each member binarises at its own cutoff, since a shared one would score
  # members on a threshold suited to whichever happens to be best calibrated.
  # A member with no cutoff falls back to 0.5.
  cutoffs <- ifelse(is.na(cutoffs), 0.5, cutoffs)
  called <- sweep(probabilities, 2, cutoffs, FUN = ">=")

  list(
    mean = rowMeans(probabilities, na.rm = TRUE),
    weighted_mean = as.numeric(probabilities %*% weights),
    median = apply(probabilities, 1, stats::median, na.rm = TRUE),
    committee = rowMeans(called, na.rm = TRUE),
    algorithm_sd = if (ncol(probabilities) > 1) {
      apply(probabilities, 1, stats::sd, na.rm = TRUE)
    } else {
      rep(0, nrow(probabilities))
    },
    algorithm_range = apply(probabilities, 1, max, na.rm = TRUE) -
      apply(probabilities, 1, min, na.rm = TRUE)
  )
}

#' The members' cross-validated metrics, stacked
#'
#' One `tune::collect_metrics()` table per member with a `type` column added, so
#' the run's `cv_metrics.csv` says which algorithm each row belongs to instead
#' of silently reporting one of them.
#'
#' @param members the [fit_patch_model()] results
#' @return a data frame
#' @keywords internal
member_metrics <- function(members) {
  tables <- lapply(names(members), function(type) {
    table <- members[[type]]$metrics
    if (is.null(table) || nrow(table) == 0) return(NULL)
    table$type <- type
    table
  })
  tables <- Filter(Negate(is.null), tables)
  if (length(tables) == 0) return(NULL)
  do.call(rbind, lapply(tables, as.data.frame))
}

#' Variable importance across an ensemble
#'
#' Each member's permutation importance, weighted by the member's weight and
#' summed. Permutation importance is the drop in ROC AUC when a predictor is
#' shuffled, which is the same quantity on the same scale for all four types —
#' that is exactly why the package computes it itself rather than asking each
#' engine — so averaging across them means something.
#'
#' The per-member columns are kept beside the ensemble figure. A predictor the
#' forest leans on and the GLM ignores is a fact about the shape of the
#' relationship, and the average is the one number that hides it.
#'
#' @param members the qualifying [fit_patch_model()] results
#' @param weights their weights
#' @return a tibble of `variable`, `importance`, and one column per member
#' @keywords internal
ensemble_importance <- function(members, weights) {
  variables <- Reduce(union, lapply(members, function(m) m$importance$variable))
  if (length(variables) == 0) {
    return(tibble::tibble(variable = character(), importance = numeric()))
  }

  per_member <- vapply(members, function(m) {
    m$importance$importance[match(variables, m$importance$variable)]
  }, numeric(length(variables)))
  per_member <- matrix(per_member, nrow = length(variables),
                       dimnames = list(NULL, names(members)))

  weights <- weights[colnames(per_member)]
  weights[is.na(weights)] <- 0
  if (sum(weights) == 0) weights <- rep(1, length(weights))
  weights <- weights / sum(weights)

  filled <- per_member
  filled[is.na(filled)] <- 0

  out <- tibble::tibble(variable = variables,
                        importance = as.numeric(filled %*% weights))
  for (type in colnames(per_member)) out[[type]] <- per_member[, type]
  dplyr::arrange(out, dplyr::desc(.data$importance))
}

#' Predict an ensemble across a covariate grid
#'
#' Every qualifying member predicts every cell, and the four rules plus the
#' spread come out of the same matrix. The `suitability` layer is whichever rule
#' `model.ensemble.rule` names; the rest go beside it, so a run can be read
#' against a different rule without refitting anything.
#'
#' `algorithm_sd` is the one to look at. It is disagreement between algorithms
#' on the same cell, which is a different question from `suitability_sd` — the
#' spread of one algorithm refitted on resampled stations — and a different one
#' again from `novelty`. A cell can be quiet on one and loud on another.
#'
#' @param ensemble a `taupatch_ensemble` from [fit_patch_ensemble()]
#' @param grid a covariate grid from `covariate_grid()`
#' @param uncertainty settings from [uncertainty_settings()], or `NULL`
#' @return a tibble of `lon`, `lat`, `suitability`, the other rules, the
#'   algorithm spread, and the per-member surfaces; `NULL` if no complete rows
#' @keywords internal
predict_grid_ensemble <- function(ensemble, grid, uncertainty = NULL) {
  complete <- grid[stats::complete.cases(grid[ensemble$predictors]), ]
  if (nrow(complete) == 0) return(NULL)

  keep <- ensemble$summary$type[ensemble$summary$qualifies]
  members <- ensemble$members[keep]

  predictions <- lapply(members, function(member) {
    tryCatch(
      stats::predict(member$workflow, new_data = complete, type = "prob")$.pred_patch,
      error = function(e) NULL
    )
  })
  usable <- !vapply(predictions, is.null, logical(1))
  if (sum(usable) == 0) return(NULL)

  probabilities <- do.call(cbind, predictions[usable])
  colnames(probabilities) <- names(members)[usable]
  cutoffs <- vapply(members[usable],
                    function(m) m$classification_threshold %||% NA_real_,
                    numeric(1))
  combined <- combine_members(probabilities, ensemble$weights, cutoffs)

  out <- tibble::tibble(
    lon = complete$lon,
    lat = complete$lat,
    suitability = combined[[ensemble$rule]],
    algorithm_sd = combined$algorithm_sd,
    algorithm_range = combined$algorithm_range,
    n_algorithms = sum(usable)
  )
  # Every rule the run did not pick, named for what it is rather than as
  # `suitability_2`, so a GeoTIFF's layer names say which is which.
  for (rule in setdiff(ensemble_rules(), ensemble$rule)) {
    out[[paste0("suitability_", rule)]] <- combined[[rule]]
  }
  for (type in colnames(probabilities)) {
    out[[paste0("member_", type)]] <- probabilities[, type]
  }

  if (is.null(uncertainty)) return(out)

  # The resample interval, if one is wanted, is the weighted pooling of each
  # member's own - so a cell's interval covers both refitting and the choice of
  # algorithm rather than only whichever was asked for.
  spread <- ensemble_member_spread(members[usable], ensemble$weights, complete,
                                    uncertainty$level)
  if (!is.null(spread)) out <- dplyr::bind_cols(out, spread)

  if (isTRUE(uncertainty$novelty)) {
    out <- dplyr::bind_cols(
      out, novelty_surface(complete, ensemble$model_data, ensemble$predictors)
    )
  }
  out
}

#' Pool the members' resample intervals
#'
#' Each member carries its own resample ensemble when `projection.uncertainty`
#' is on. Rather than reporting one member's interval, or four of them, this
#' pools every member's every replicate into one set and takes the interval from
#' that — so the reported interval covers refit variability *and* algorithm
#' choice at once, which is what a reader of a single interval column assumes it
#' does.
#'
#' Members are represented in proportion to their weight by drawing that share
#' of the pooled columns, so a member with a tenth of the weight does not
#' contribute a quarter of the interval just for having been fitted.
#'
#' @param members the qualifying members that predicted successfully
#' @param weights their weights
#' @param newdata the cells to predict
#' @param level interval width
#' @return a data frame of `suitability_sd`, `suitability_lower`,
#'   `suitability_upper` and `n_members`; `NULL` when no member has an ensemble
#' @keywords internal
ensemble_member_spread <- function(members, weights, newdata, level = 0.9) {
  weights <- weights[names(members)]
  weights[is.na(weights)] <- 0
  if (sum(weights) == 0) weights <- rep(1, length(members))
  weights <- weights / sum(weights)

  sizes <- vapply(members, function(m) length(m$ensemble %||% list()), integer(1))
  if (sum(sizes) == 0) return(NULL)

  # The pool is sized by the largest member's ensemble, so the shares are whole
  # replicates rather than fractions of one.
  budget <- max(sizes)
  columns <- lapply(names(members), function(type) {
    members_ensemble <- members[[type]]$ensemble
    take <- min(length(members_ensemble),
                max(1L, round(weights[[type]] * budget * length(members))))
    if (take == 0) return(NULL)
    ensemble_spread_matrix(members_ensemble[seq_len(take)], newdata)
  })
  columns <- Filter(Negate(is.null), columns)
  if (length(columns) == 0) return(NULL)

  pooled <- do.call(cbind, columns)
  if (is.null(pooled) || ncol(pooled) < 2) return(NULL)

  tail <- (1 - level) / 2
  data.frame(
    suitability_sd = apply(pooled, 1, stats::sd, na.rm = TRUE),
    suitability_lower = apply(pooled, 1, stats::quantile, probs = tail,
                              na.rm = TRUE, names = FALSE),
    suitability_upper = apply(pooled, 1, stats::quantile, probs = 1 - tail,
                              na.rm = TRUE, names = FALSE),
    n_members = ncol(pooled)
  )
}

#' Predictions from every member of one resample ensemble, as a matrix
#'
#' The half of [ensemble_spread()] that produces the numbers, without reducing
#' them — so an ensemble of ensembles can pool the replicates before taking
#' quantiles rather than taking quantiles of quantiles.
#'
#' @param ensemble a list of fitted workflows
#' @param newdata the cells to predict
#' @return a matrix of cells by members, or `NULL`
#' @keywords internal
ensemble_spread_matrix <- function(ensemble, newdata) {
  if (length(ensemble) == 0) return(NULL)
  predictions <- lapply(ensemble, function(member) {
    tryCatch(
      stats::predict(member, new_data = newdata, type = "prob")$.pred_patch,
      error = function(e) NULL
    )
  })
  predictions <- Filter(Negate(is.null), predictions)
  if (length(predictions) == 0) return(NULL)
  do.call(cbind, predictions)
}

#' Print an ensemble
#'
#' @param x a `taupatch_ensemble`
#' @param ... unused
#' @return `x`, invisibly
#' @export
print.taupatch_ensemble <- function(x, ...) {
  cat("<taupatch ensemble>\n")
  cat("  rule:  ", x$rule, "\n", sep = "")
  cat("  members (", sum(x$summary$qualifies), " of ", nrow(x$summary),
      " qualifying):\n", sep = "")
  print(x$summary[c("type", "score", "metric", "qualifies", "weight")],
        row.names = FALSE)

  auc <- x$evaluation$value[x$evaluation$metric == "roc_auc" &
                              is.na(x$evaluation$threshold)]
  if (length(auc) == 1) {
    cat("\n  ensemble ROC AUC (out of fold): ", signif(auc, 4), "\n", sep = "")
  }
  cat("  classification threshold: ", signif(x$classification_threshold, 4),
      "\n", sep = "")
  invisible(x)
}
