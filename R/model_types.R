#' Model types a run can fit
#'
#' The original fitted one thing. These four are the ones a habitat suitability
#' study actually chooses between, and they disagree in ways worth seeing: if a
#' GLM and a random forest rank the same stations, the relationships are close to
#' monotonic and the forest is not buying much; if they disagree sharply, either
#' the response is genuinely non-linear or the forest is fitting noise.
#'
#' Each entry names a `parsnip` model function and the engine behind it. `tunable`
#' lists the hyperparameters `model.tune` will search — a GLM has none, which is
#' a property of the model rather than an omission.
#'
#' @return a named list, one entry per type, each with `label`, `engine`,
#'   `package`, `description`, `tunable`, `needs_formula`, and `spec`
#' @examples
#' names(model_types())
#' model_types()$gam$description
#' vapply(model_types(), function(m) m$engine, character(1))
#' @seealso [build_model_spec()], which turns a config into a fitted-ready spec
#' @export
model_types <- function() {
  list(
    rf = list(
      label = "Random forest",
      engine = "ranger",
      package = "ranger",
      description = paste(
        "Bagged decision trees. Handles interactions and non-linearity without",
        "being told about them, tolerates correlated predictors, and is hard to",
        "make fail - which is why it is the default and also why it is worth",
        "checking against something simpler."
      ),
      tunable = c("mtry", "min_n"),
      needs_formula = FALSE,
      spec = function(config, tuning) {
        args <- list(trees = config$model$trees)
        args$mtry <- if (tuning) tune::tune() else config$model$mtry
        args$min_n <- if (tuning) tune::tune() else config$model$min_n
        args <- args[!vapply(args, is.null, logical(1))]

        do.call(parsnip::rand_forest, args) |>
          parsnip::set_engine("ranger") |>
          parsnip::set_mode("classification")
      }
    ),
    brt = list(
      label = "Boosted regression trees",
      engine = "xgboost",
      package = "xgboost",
      description = paste(
        "Trees fitted in sequence, each correcting what the last got wrong.",
        "Usually the strongest of these on tabular data, and the most willing to",
        "overfit: `learn_rate` and `trees` trade against each other, and the",
        "defaults here are deliberately slow-and-many rather than fast-and-few."
      ),
      tunable = c("tree_depth", "learn_rate", "min_n"),
      needs_formula = FALSE,
      spec = function(config, tuning) {
        args <- list(trees = config$model$trees)
        args$tree_depth <- if (tuning) tune::tune() else config$model$tree_depth %||% 6
        args$learn_rate <- if (tuning) tune::tune() else config$model$learn_rate %||% 0.05
        args$min_n <- if (tuning) tune::tune() else config$model$min_n

        args <- args[!vapply(args, is.null, logical(1))]
        do.call(parsnip::boost_tree, args) |>
          parsnip::set_engine("xgboost") |>
          parsnip::set_mode("classification")
      }
    ),
    glm = list(
      label = "Logistic regression",
      engine = "glm",
      package = "stats",
      description = paste(
        "Linear on the log-odds scale. The one model here whose coefficients read",
        "directly as effects, and the honest baseline: a flexible model that",
        "cannot beat it on held-out folds has not found anything a straight line",
        "was missing."
      ),
      tunable = character(),
      needs_formula = FALSE,
      spec = function(config, tuning) {
        parsnip::logistic_reg() |>
          parsnip::set_engine("glm") |>
          parsnip::set_mode("classification")
      }
    ),
    gam = list(
      label = "Generalized additive model",
      engine = "mgcv",
      package = "mgcv",
      description = paste(
        "A smooth function of each predictor, added together. The middle ground:",
        "it bends where the data says to, and because each term is a curve you",
        "can plot, it says what shape it found - which a forest cannot. Set",
        "`select_features: true` to let it shrink a useless term to zero."
      ),
      tunable = "adjust_deg_free",
      needs_formula = TRUE,
      spec = function(config, tuning) {
        args <- list(select_features = isTRUE(config$model$select_features))
        if (tuning) args$adjust_deg_free <- tune::tune()

        do.call(parsnip::gen_additive_mod, args) |>
          parsnip::set_engine("mgcv") |>
          parsnip::set_mode("classification")
      }
    )
  )
}

#' Which model type a config asks for
#'
#' `model.type` names it. A config written before there was a choice says only
#' `model.engine: ranger`, so an engine that identifies a type unambiguously is
#' accepted as one — those configs keep meaning what they meant.
#'
#' @param config a config list, as returned by `load_config()`
#' @return the model type name
#' @keywords internal
resolve_model_type <- function(config) {
  catalog <- model_types()
  type <- config$model$type

  if (is.null(type)) {
    engine <- config$model$engine
    if (is.null(engine)) return("rf")
    match <- names(catalog)[vapply(catalog, function(m) m$engine == engine,
                                    logical(1))]
    if (length(match) == 1) return(match)
    stop("model.engine '", engine, "' does not identify a model type. Set ",
         "model.type to one of: ", paste(names(catalog), collapse = ", "),
         call. = FALSE)
  }

  if (!(type %in% names(catalog))) {
    stop("Unknown model.type '", type, "'.\nAvailable: ",
         paste(names(catalog), collapse = ", "), call. = FALSE)
  }
  type
}

#' Build the model specification
#'
#' Random forest by default, matching the original. Which model is fitted is a
#' config field rather than baked into the code, so comparing a forest against a
#' GAM is a one-word edit — which is what the app's model picker exposes.
#'
#' @param config a config list, as returned by `load_config()`
#' @return a `parsnip` model specification
#' @keywords internal
build_model_spec <- function(config) {
  type <- resolve_model_type(config)
  entry <- model_types()[[type]]

  tuning <- isTRUE(config$model$tune)
  if (tuning && length(entry$tunable) == 0) {
    stop("model.tune is true, but ", entry$label, " has no hyperparameters to ",
         "tune. Set model.tune to false, or choose a type that does: ",
         paste(names(Filter(function(m) length(m$tunable) > 0, model_types())),
               collapse = ", "), call. = FALSE)
  }

  # parsnip captures its arguments as quosures, so the values must be resolved
  # before the call. Passing `if (tuning) tune() else x` directly stores the
  # unevaluated expression, and parsnip then sees a literal tune() in it and
  # treats the argument as tagged for tuning even when it isn't.
  entry$spec(config, tuning)
}

#' Check that the packages a model type needs are installed
#'
#' Checked before fitting rather than at load, since a run needs only the one
#' type it asks for and nothing here is a hard dependency.
#'
#' @param type a model type name
#' @return `TRUE` invisibly; errors otherwise
#' @keywords internal
check_model_packages <- function(type) {
  entry <- model_types()[[type]]
  needed <- setdiff(entry$package, "stats")

  for (package in needed) {
    if (!requireNamespace(package, quietly = TRUE)) {
      stop("model.type '", type, "' (", entry$label, ") needs the '", package,
           "' package. Install it with install.packages('", package, "').",
           call. = FALSE)
    }
  }
  invisible(TRUE)
}

#' Formula for a model type that needs one
#'
#' `mgcv` has to be told which terms are smooth, and `parsnip` passes that as a
#' formula rather than as arguments. Every predictor gets a smooth except those
#' with too few distinct values to support one: a thin-plate spline needs more
#' unique points than it has basis functions, and `s()` on a near-constant column
#' fails rather than degrading. Those enter linearly, which is what a smooth
#' would have reduced to anyway.
#'
#' @param type a model type name
#' @param model_data the data the model will be fitted on
#' @param predictors predictor column names
#' @return a formula, or `NULL` for types that do not need one
#' @keywords internal
model_formula <- function(type, model_data, predictors) {
  if (!isTRUE(model_types()[[type]]$needs_formula)) return(NULL)

  # mgcv's default basis is 10 functions, so a smooth needs more than 10
  # distinct values to be identifiable.
  terms <- vapply(predictors, function(v) {
    distinct <- length(unique(stats::na.omit(model_data[[v]])))
    if (distinct > 10) paste0("s(", v, ")") else v
  }, character(1))

  stats::as.formula(paste("patch ~", paste(terms, collapse = " + ")))
}

#' Permutation variable importance, for any model type
#'
#' How much worse the model ranks stations when one predictor is shuffled: the
#' drop in ROC AUC, averaged over several shuffles. Zero means the predictor
#' carried nothing the others did not.
#'
#' This replaces `ranger`'s built-in importance, which existed only because the
#' only model was a random forest. A GLM and a GAM have no such thing, and the
#' importances that engines do report are not comparable — ranger's permutation
#' drop and xgboost's split gain are different quantities on different scales, so
#' reading one against the other says nothing. Computing it here means one
#' definition for all four types, which is what makes comparing them meaningful.
#'
#' Measured on the training data, since the fitted workflow is what is being
#' interrogated. That inflates the absolute values for a model that overfits, but
#' the ranking — which is what the plot is read for — holds up.
#'
#' @param fitted a fitted `workflows::workflow()`
#' @param model_data the data it was fitted on, including the `patch` column
#' @param predictors predictor column names
#' @param times how many shuffles to average over
#' @return a tibble of `variable` and `importance`, most important first
#' @keywords internal
permutation_importance <- function(fitted, model_data, predictors, times = 5) {
  auc <- function(data) {
    probabilities <- stats::predict(fitted, new_data = data, type = "prob")
    # `patch` is the first factor level, which is the event yardstick scores by
    # default.
    yardstick::roc_auc_vec(data$patch, probabilities$.pred_patch)
  }

  baseline <- tryCatch(auc(model_data), error = function(e) NA_real_)
  if (is.na(baseline)) {
    return(tibble::tibble(variable = character(), importance = numeric()))
  }

  importance <- vapply(predictors, function(variable) {
    drops <- vapply(seq_len(times), function(i) {
      shuffled <- model_data
      shuffled[[variable]] <- sample(shuffled[[variable]])
      baseline - tryCatch(auc(shuffled), error = function(e) NA_real_)
    }, numeric(1))
    mean(drops, na.rm = TRUE)
  }, numeric(1))

  tibble::tibble(variable = predictors, importance = unname(importance)) |>
    dplyr::arrange(dplyr::desc(.data$importance))
}
