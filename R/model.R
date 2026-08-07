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
#' @references
#' Kuhn M, Wickham H (2020). *Tidymodels: a collection of packages for modeling
#' and machine learning using tidyverse principles*.
#' <https://www.tidymodels.org>
#'
#' Thuiller W, Lafourcade B, Engler R, Araújo MB (2009). BIOMOD - a platform for
#' ensemble forecasting of species distributions. *Ecography* **32**(3),
#' 369-373. \doi{10.1111/j.1600-0587.2008.05742.x} — what this replaces
#'
#' See [model_types()] for the reference behind each model, and
#' [evaluation_table()] for the metrics.
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
  #
  # The fold models are kept too when a projection interval is wanted. They are
  # fitted either way and normally discarded, so asking for them back is free -
  # the cost of the interval is entirely in predicting from them later.
  uncertainty <- uncertainty_settings(config)
  keep_models <- !is.null(uncertainty) && identical(uncertainty$method, "folds")
  control <- if (keep_models) {
    tune::control_resamples(save_pred = TRUE, extract = function(x) x)
  } else {
    tune::control_resamples(save_pred = TRUE)
  }

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

  # The point estimate stays the model fitted on everything. The ensemble only
  # ever adds columns beside it, so turning uncertainty on never moves a map.
  ensemble <- if (is.null(uncertainty)) {
    list()
  } else {
    projection_ensemble(resampled, wf, model_data, uncertainty)
  }

  list(
    workflow = fitted,
    metrics = cv_metrics,
    evaluation = evaluation_table(predictions, cv_metrics, cutoff),
    predictions = predictions,
    classification_threshold = cutoff,
    importance = permutation_importance(fitted, model_data, predictors),
    ensemble = ensemble,
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
#' @references
#' Allouche O, Tsoar A, Kadmon R (2006). Assessing the accuracy of species
#' distribution models: prevalence, kappa and the true skill statistic (TSS).
#' *Journal of Applied Ecology* **43**(6), 1223-1232.
#' \doi{10.1111/j.1365-2664.2006.01214.x} — `tss`
#'
#' Saito T, Rehmsmeier M (2015). The precision-recall plot is more informative
#' than the ROC plot when evaluating binary classifiers on imbalanced datasets.
#' *PLoS ONE* **10**(3), e0118432. \doi{10.1371/journal.pone.0118432} — `pr_auc`
#'
#' Sofaer HR, Hoeting JA, Jarnevich CS (2019). The area under the
#' precision-recall curve as a performance metric for rare binary events.
#' *Methods in Ecology and Evolution* **10**(4), 565-577.
#' \doi{10.1111/2041-210X.13140} — the same argument for rare events in species
#' distribution models, which is what a patch is
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
#' @references
#' Allouche O, Tsoar A, Kadmon R (2006). Assessing the accuracy of species
#' distribution models: prevalence, kappa and the true skill statistic (TSS).
#' *Journal of Applied Ecology* **43**(6), 1223-1232.
#' \doi{10.1111/j.1365-2664.2006.01214.x}
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

