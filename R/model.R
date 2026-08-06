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
#'   performance), `importance` (permutation variable importance), `predictors`,
#'   and `threshold`
#' @export
fit_patch_model <- function(dat, config) {
  if (!requireNamespace("ranger", quietly = TRUE)) {
    stop("The 'ranger' package is required. Install it with install.packages('ranger').",
         call. = FALSE)
  }
  set.seed(config$model$seed)

  predictors <- predictor_names(dat, config)
  if (length(predictors) == 0) {
    stop("No numeric predictors found. Check that covariates were attached.", call. = FALSE)
  }

  model_data <- dat[c(predictors, "patch")] |> as.data.frame()

  rec <- build_recipe(model_data, config)
  spec <- build_model_spec(config)
  wf <- workflows::workflow() |>
    workflows::add_recipe(rec) |>
    workflows::add_model(spec)

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
    importance = extract_importance(fitted),
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
#' Log-transforms the covariates named in `covariates.log_transform`, then
#' normalizes all numeric predictors. The original applied `log(abs(x))` to a
#' hardcoded trio of chlorophyll, integrated chlorophyll, and bathymetry
#' (`original/buildZoopModel.R:134-136`); which covariates need it is now config.
#'
#' The transform is `log1p(abs(x))` rather than `step_log()`. It preserves the
#' original's `abs()`, which exists because bathymetry is stored as negative
#' depth, while remaining defined at zero — `step_log(signed = TRUE)` returns
#' `-Inf` at zero and silently ignores an `offset` meant to prevent that, and
#' zeros are common in these covariates.
#'
#' @param model_data data frame of predictors plus the `patch` response
#' @param config a config list, as returned by `load_config()`
#' @return a `recipes::recipe`
#' @keywords internal
build_recipe <- function(model_data, config) {
  rec <- recipes::recipe(patch ~ ., data = model_data)

  log_vars <- intersect(config$covariates$log_transform, names(model_data))
  if (length(log_vars) > 0) {
    rec <- recipes::step_mutate_at(rec, dplyr::all_of(log_vars),
                                    fn = function(x) log1p(abs(x)))
  }

  rec |>
    recipes::step_normalize(recipes::all_numeric_predictors()) |>
    recipes::step_naomit(recipes::all_predictors(), skip = TRUE)
}

#' Build the model specification
#'
#' Random forest by default, matching the original. Because the engine is a config
#' field rather than baked into the code, swapping in another classifier is a
#' config change — which is what the GUI's model picker exposes.
#'
#' @param config a config list, as returned by `load_config()`
#' @return a `parsnip` model specification
#' @keywords internal
build_model_spec <- function(config) {
  tuning <- isTRUE(config$model$tune)

  # parsnip captures its arguments as quosures, so the values must be resolved
  # before the call. Passing `if (tuning) tune() else x` directly stores the
  # unevaluated expression, and parsnip then sees a literal tune() in it and
  # treats the argument as tagged for tuning even when it isn't.
  args <- list(trees = config$model$trees)
  mtry <- if (tuning) tune::tune() else config$model$mtry
  min_n <- if (tuning) tune::tune() else config$model$min_n
  if (!is.null(mtry)) args$mtry <- mtry
  if (!is.null(min_n)) args$min_n <- min_n

  do.call(parsnip::rand_forest, args) |>
    parsnip::set_engine(config$model$engine, importance = "permutation") |>
    parsnip::set_mode("classification")
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

#' Extract permutation variable importance
#'
#' Read from the underlying `ranger` fit rather than via an extra package, since
#' the engine already computes it.
#'
#' @param fitted a fitted workflow
#' @return a tibble of `variable` and `importance`, most important first
#' @keywords internal
extract_importance <- function(fitted) {
  engine_fit <- workflows::extract_fit_engine(fitted)
  importance <- engine_fit$variable.importance
  if (is.null(importance)) {
    return(tibble::tibble(variable = character(), importance = numeric()))
  }
  tibble::tibble(variable = names(importance), importance = unname(importance)) |>
    dplyr::arrange(dplyr::desc(.data$importance))
}
