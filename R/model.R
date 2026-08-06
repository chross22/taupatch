#' Fit a patch habitat suitability model
#'
#' Fits a tidymodels workflow classifying stations as inside or outside a
#' high-abundance patch. Replaces the `biomod2` model in
#' `original/buildZoopModel.R`: cross-validation via `rsample::vfold_cv()` instead
#' of biomod2's `CV.nb.rep`/`data.split.perc`, and a `workflows::workflow()` object
#' instead of biomod2's on-disk model directory and string-pasted run names.
#'
#' @param dat labeled modeling data from `label_patch()` with covariates attached
#' @param config a config list, as returned by `load_config()`
#' @return a list with `workflow` (the fitted workflow), `metrics` (cross-validated
#'   performance), `importance` (permutation variable importance), `type` (the
#'   model type fitted), `model_data` (what it was fitted on), `predictors`, and
#'   `threshold`
#' @export
fit_patch_model <- function(dat, config) {
  type <- resolve_model_type(config)
  check_model_packages(type)
  set.seed(config$model$seed)

  predictors <- predictor_names(dat, config)
  if (length(predictors) == 0) {
    stop("No numeric predictors found. Check that covariates were attached.", call. = FALSE)
  }

  model_data <- dat[c(predictors, "patch")] |> as.data.frame()

  rec <- build_recipe(model_data, config)
  spec <- build_model_spec(config)

  # mgcv has to be told which terms are smooth, and parsnip passes that as a
  # formula. The other three take their predictors from the recipe.
  formula <- model_formula(type, model_data, predictors, config)
  wf <- workflows::workflow() |>
    workflows::add_recipe(rec)
  wf <- if (is.null(formula)) {
    workflows::add_model(wf, spec)
  } else {
    workflows::add_model(wf, spec, formula = formula)
  }

  folds <- rsample::vfold_cv(model_data, v = config$model$cv_folds, strata = "patch")
  metrics <- patch_metric_set()

  # Predictions are retained so an ROC curve can be drawn from held-out folds.
  # Without this, only the summary metrics survive resampling and the curve
  # would have to be redrawn on training data, which flatters the model.
  control <- tune::control_resamples(save_pred = TRUE)

  if (isTRUE(config$model$tune)) {
    tuned <- tune::tune_grid(wf, resamples = folds, grid = config$model$tune_grid %||% 10,
                             metrics = metrics)
    best <- tune::select_best(tuned, metric = "roc_auc")
    wf <- tune::finalize_workflow(wf, best)
    resampled <- tune::fit_resamples(wf, resamples = folds, metrics = metrics,
                                     control = control)
  } else {
    resampled <- tune::fit_resamples(wf, resamples = folds, metrics = metrics,
                                     control = control)
  }

  cv_metrics <- add_tss(tune::collect_metrics(resampled))
  fitted <- parsnip::fit(wf, data = model_data)

  predictions <- tune::collect_predictions(resampled)
  cutoff <- optimal_threshold(predictions)

  list(
    workflow = fitted,
    metrics = cv_metrics,
    evaluation = evaluation_table(predictions, cv_metrics, cutoff),
    predictions = predictions,
    classification_threshold = cutoff,
    importance = permutation_importance(fitted, model_data, predictors),
    type = type,
    # Kept so diagnostics that need to re-predict - partial effects above all -
    # can be produced without refitting. It is the station table, so hundreds to
    # a few thousand rows.
    model_data = model_data,
    predictors = predictors,
    threshold = attr(dat, "threshold")
  )
}

#' Assemble a self-explanatory evaluation table
#'
#' The cross-validated metrics table reports sensitivity, specificity and kappa
#' at the default 0.5 cutoff without saying so anywhere. That is badly misleading
#' when the classes are imbalanced — and they are here by construction, since a
#' 90th-percentile abundance threshold makes only a tenth of stations patches. At
#' 0.5 a random forest calls almost nothing a patch, so sensitivity reads as poor
#' when the model is not.
#'
#' This states the cutoff each metric belongs to, and reports the
#' threshold-dependent ones twice: at 0.5, and at the cutoff that maximises TSS.
#' Threshold-free metrics carry `NA` in that column, which is the honest entry —
#' they do not have one.
#'
#' @param predictions held-out predictions from resampling
#' @param cv_metrics the `tune::collect_metrics()` result, with TSS added
#' @param cutoff the TSS-maximising cutoff
#' @return a data frame with `metric`, `threshold`, `value`, `std_err`, and
#'   `note` columns
#' @keywords internal
evaluation_table <- function(predictions, cv_metrics, cutoff) {
  threshold_free <- c("roc_auc", "pr_auc")

  ranking <- data.frame(
    metric = threshold_free,
    threshold = NA_real_,
    value = c(
      value_or_na(cv_metrics, "roc_auc"),
      yardstick::pr_auc(predictions, truth = "patch", ".pred_patch")$.estimate
    ),
    std_err = c(std_err_or_na(cv_metrics, "roc_auc"), NA_real_),
    note = "ranking quality; does not depend on a cutoff",
    stringsAsFactors = FALSE
  )

  at_default <- metrics_at(predictions, 0.5)
  at_default$std_err <- vapply(at_default$metric, function(m) std_err_or_na(cv_metrics, m),
                                numeric(1))
  at_default$note <- "default cutoff; usually poor when classes are imbalanced"

  at_best <- metrics_at(predictions, cutoff)
  at_best$std_err <- NA_real_
  at_best$note <- "TSS-optimal cutoff; use this one to binarise a projection"

  out <- rbind(ranking, at_default, at_best)
  rownames(out) <- NULL
  out
}

#' Threshold-dependent metrics at one cutoff
#'
#' Computed from the pooled held-out predictions rather than per fold, so these
#' have no standard error — the fold structure is used up by the pooling.
#'
#' @param predictions held-out predictions from resampling
#' @param cutoff probability at or above which a cell is called a patch
#' @return a data frame of `metric`, `threshold`, `value`
#' @keywords internal
metrics_at <- function(predictions, cutoff) {
  if (is.na(cutoff)) {
    return(data.frame(metric = character(), threshold = numeric(),
                      value = numeric(), stringsAsFactors = FALSE))
  }
  called <- predictions$.pred_patch >= cutoff
  is_patch <- predictions$patch == "patch"

  sens <- sum(called & is_patch) / sum(is_patch)
  spec <- sum(!called & !is_patch) / sum(!is_patch)
  precision <- if (sum(called) > 0) sum(called & is_patch) / sum(called) else NA_real_

  data.frame(
    metric = c("sens", "spec", "tss", "precision"),
    threshold = cutoff,
    value = c(sens, spec, sens + spec - 1, precision),
    stringsAsFactors = FALSE
  )
}

#' Pull one metric's mean from a collect_metrics() table
#'
#' @param cv_metrics a metrics table
#' @param metric the metric name
#' @return the mean, or `NA_real_` if absent
#' @keywords internal
value_or_na <- function(cv_metrics, metric) {
  value <- cv_metrics$mean[cv_metrics$.metric == metric]
  if (length(value) == 1) value else NA_real_
}

#' Pull one metric's standard error from a collect_metrics() table
#'
#' @param cv_metrics a metrics table
#' @param metric the metric name
#' @return the standard error, or `NA_real_` if absent
#' @keywords internal
std_err_or_na <- function(cv_metrics, metric) {
  value <- cv_metrics$std_err[cv_metrics$.metric == metric]
  if (length(value) == 1) value else NA_real_
}

#' Probability cutoff that maximises TSS
#'
#' The metrics table reports sensitivity and specificity at the default 0.5
#' cutoff, which is rarely right when the classes are imbalanced — and they are
#' here by construction, since a 90th-percentile abundance threshold makes only
#' 10% of stations patches. At 0.5 a random forest will call almost nothing a
#' patch, so sensitivity looks far worse than the model can actually achieve.
#'
#' This is the cutoff the original pipeline was reaching for with
#' `metric.binary = 'ROC'` when it binarised its projections.
#'
#' @param predictions held-out predictions from resampling
#' @return the TSS-maximising cutoff, or `NA_real_` if it cannot be computed
#' @keywords internal
optimal_threshold <- function(predictions) {
  if (is.null(predictions) || !".pred_patch" %in% names(predictions)) {
    return(NA_real_)
  }
  curve <- yardstick::roc_curve(predictions, truth = "patch", ".pred_patch")
  curve <- curve[is.finite(curve$.threshold), ]
  if (nrow(curve) == 0) return(NA_real_)

  curve$.threshold[which.max(curve$sensitivity + curve$specificity - 1)]
}

#' Build the preprocessing recipe
#'
#' Applies the transformations named in `covariates.transform`, then normalizes
#' all numeric predictors unless `covariates.normalize` turns that off. The
#' original applied `log(abs(x))` to a hardcoded trio of chlorophyll, integrated
#' chlorophyll, and bathymetry (`original/buildZoopModel.R:134-136`); which
#' covariates need which transform is now config. See [covariate_transforms()]
#' for what is available and what each one can safely be given.
#'
#' The default transform remains `log1p(abs(x))` rather than `step_log()`. It
#' preserves the original's `abs()`, which exists because bathymetry is stored as
#' negative depth, while remaining defined at zero — `step_log(signed = TRUE)`
#' returns `-Inf` at zero and silently ignores an `offset` meant to prevent that,
#' and zeros are common in these covariates.
#'
#' Normalizing costs a tree model nothing and matters to everything else, so it
#' stays on by default and is a knob rather than a decision the engine choice
#' makes silently.
#'
#' @param model_data data frame of predictors plus the `patch` response
#' @param config a config list, as returned by `load_config()`
#' @return a `recipes::recipe`
#' @keywords internal
build_recipe <- function(model_data, config) {
  rec <- recipes::recipe(patch ~ ., data = model_data)

  catalog <- covariate_transforms()
  spec <- covariate_transform_spec(config)
  for (name in names(spec)) {
    vars <- intersect(spec[[name]], names(model_data))
    if (length(vars) == 0) next

    entry <- catalog[[name]]
    for (covariate in vars) {
      check_transform_input(model_data[[covariate]], covariate, name, entry)
    }
    rec <- add_transform_step(rec, vars, entry)
  }

  if (!isFALSE(config$covariates$normalize)) {
    rec <- recipes::step_normalize(rec, recipes::all_numeric_predictors())
  }
  recipes::step_naomit(rec, recipes::all_predictors(), skip = TRUE)
}

#' Add one transformation step to a recipe
#'
#' A function rather than inline code because `recipes` captures its selection as
#' an unevaluated quosure. Adding the steps directly inside a loop leaves every
#' one of them pointing at the same `vars` binding, which by the time `prep()`
#' runs holds the last iteration's value — so a config asking for `log10` on
#' chlorophyll and `sqrt` on temperature silently applies both to temperature and
#' neither to chlorophyll. Each call here gets its own frame, so each step's
#' quosure resolves to the variables it was built for.
#'
#' The `force()` is the load-bearing half. Without it `vars` is still an unforced
#' promise pointing back at the caller's loop variable, so moving the call into a
#' function changes nothing: the quosure captures this frame, the promise is
#' evaluated at `prep()` time, and it reads the loop variable's final value.
#'
#' @param rec a `recipes::recipe`
#' @param vars covariate names the transform applies to
#' @param entry the matching [covariate_transforms()] entry
#' @return `rec` with the step appended
#' @keywords internal
add_transform_step <- function(rec, vars, entry) {
  force(vars)
  force(entry)

  if (is.null(entry$step)) {
    return(recipes::step_mutate_at(rec, dplyr::all_of(vars), fn = entry$fn))
  }
  entry$step(rec, vars)
}

#' Metric set for patch models
#'
#' ROC AUC, Cohen's kappa, sensitivity, and specificity — the first three matching
#' the original's `metric.eval = c('ROC', 'TSS', 'KAPPA')`. TSS is derived from
#' sensitivity and specificity afterwards by `add_tss()`.
#'
#' @return a `yardstick` metric set
#' @keywords internal
patch_metric_set <- function() {
  yardstick::metric_set(yardstick::roc_auc, yardstick::kap,
                        yardstick::sens, yardstick::spec)
}

#' Add the True Skill Statistic to a metrics table
#'
#' TSS is sensitivity + specificity - 1. It is computed here from the
#' cross-validated sensitivity and specificity rather than registered as a custom
#' yardstick metric, since the value is identical and this avoids carrying a
#' custom metric class through resampling.
#'
#' @param metrics a `tune::collect_metrics()` result
#' @return `metrics` with a `tss` row appended when both inputs are present
#' @keywords internal
add_tss <- function(metrics) {
  sens <- metrics$mean[metrics$.metric == "sens"]
  spec <- metrics$mean[metrics$.metric == "spec"]
  if (length(sens) != 1 || length(spec) != 1) return(metrics)

  tss_row <- metrics[metrics$.metric == "sens", ]
  tss_row$.metric <- "tss"
  tss_row$mean <- sens + spec - 1
  tss_row$std_err <- NA_real_
  rbind(metrics, tss_row)
}

