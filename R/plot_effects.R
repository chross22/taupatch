#' Partial effect of each predictor on patch probability
#'
#' How predicted patch probability moves as one predictor is swept across its
#' range, with every other predictor held at the values it actually takes. This
#' is a partial dependence curve: for each value on the sweep, the predictor is
#' set to that value for every station, the model is asked for a probability, and
#' those are averaged.
#'
#' Importance says a predictor matters; this says what it does — whether
#' probability rises, falls, peaks in the middle, or bends somewhere particular.
#' That is most of what a habitat model is fitted to find out.
#'
#' Computed by prediction rather than read out of the fitted object, so it means
#' the same thing for all four model types and the curves can be laid against
#' each other. A GAM's own smooths are the exact version of this for a GAM alone
#' — [gam_smooth_terms()] reports those — but they are on the log-odds scale and
#' cannot be compared with a forest.
#'
#' @section What it hides:
#' Averaging over the other predictors is what makes one curve per predictor
#' possible, and it is also the limitation: an effect that reverses depending on
#' another predictor averages to something flatter than either case, and the plot
#' cannot show that it did. Two correlated predictors are also swept into
#' combinations the ocean never produces.
#'
#' @param fitted a fitted `workflows::workflow()`
#' @param model_data the data it was fitted on
#' @param predictors predictor column names
#' @param grid_size how many points to sweep each predictor across
#' @param max_rows stations to average over; the full set when smaller
#' @return a data frame with `variable`, `value`, and `probability`
#' @examples
#' \dontrun{
#' effects <- partial_effects(model$workflow, model$model_data, model$predictors)
#' }
#' @seealso [plot_partial_effects()]
#' @export
partial_effects <- function(fitted, model_data, predictors, grid_size = 20,
                            max_rows = 500) {
  # Averaging over every station costs a prediction per station per grid point.
  # A sample of them lands in the same place and keeps this seconds rather than
  # minutes on a real run.
  rows <- if (nrow(model_data) > max_rows) {
    sample(nrow(model_data), max_rows)
  } else {
    seq_len(nrow(model_data))
  }
  base <- model_data[rows, , drop = FALSE]

  curves <- lapply(predictors, function(variable) {
    column <- model_data[[variable]]

    # Quantile-spaced rather than evenly spaced, so the sweep spends its points
    # where the data is instead of stretching across an outlier's gap.
    values <- stats::quantile(column, probs = seq(0, 1, length.out = grid_size),
                              na.rm = TRUE, names = FALSE)

    # Put back into the column's own type. A quantile is a double even when the
    # column is not, and the recipe checks types on the way in - so sweeping a
    # double through `jday` fails as a lossy cast rather than plotting.
    if (is.integer(column)) values <- as.integer(round(values))
    values <- unique(values)
    if (length(values) < 2) return(NULL)

    probability <- vapply(values, function(value) {
      grid <- base
      grid[[variable]] <- value
      predicted <- stats::predict(fitted, new_data = grid, type = "prob")
      mean(predicted$.pred_patch, na.rm = TRUE)
    }, numeric(1))

    data.frame(variable = variable, value = values, probability = probability,
               stringsAsFactors = FALSE)
  })

  out <- do.call(rbind, curves)
  if (is.null(out)) {
    return(data.frame(variable = character(), value = numeric(),
                      probability = numeric(), stringsAsFactors = FALSE))
  }
  out
}

#' Plot partial effects, one panel per predictor
#'
#' @param effects a data frame from [partial_effects()]
#' @param path optional file to write the plot to instead of returning it
#' @return a `ggplot` object, or `path` invisibly when writing
#' @examples
#' \dontrun{
#' plot_partial_effects(partial_effects(model$workflow, model$model_data,
#'                                      model$predictors))
#' }
#' @export
plot_partial_effects <- function(effects, path = NULL) {
  if (nrow(effects) == 0) {
    stop("No partial effects to plot.", call. = FALSE)
  }

  p <- ggplot2::ggplot(effects, ggplot2::aes(x = .data$value,
                                              y = .data$probability)) +
    ggplot2::geom_line(linewidth = 0.7, colour = "#2c7fb8") +
    ggplot2::facet_wrap(~ .data$variable, scales = "free_x") +
    ggplot2::labs(x = NULL, y = "Predicted patch probability") +
    ggplot2::theme_minimal() +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  if (is.null(path)) return(p)
  panels <- length(unique(effects$variable))
  ggplot2::ggsave(path, plot = p, dpi = 150,
                  width = 9, height = max(3, 2.2 * ceiling(panels / 3)))
  invisible(path)
}

#' Coefficients of a fitted logistic regression
#'
#' What a GLM has that the others do not: a signed, testable number per
#' predictor. Because the recipe centres and scales, these are on a common scale
#' and can be read against each other — a coefficient of 0.8 moves the log-odds
#' by 0.8 per standard deviation of its predictor.
#'
#' @param fitted a fitted `workflows::workflow()` whose model is a `glm`
#' @return a data frame of `variable`, `estimate`, `std_error`, `statistic`,
#'   `p_value`, and the 95% interval as `lower`/`upper`
#' @examples
#' \dontrun{
#' glm_coefficients(model$workflow)
#' }
#' @export
glm_coefficients <- function(fitted) {
  engine <- model_engine_fit(fitted)
  coefficients <- summary(engine)$coefficients

  out <- data.frame(
    variable = rownames(coefficients),
    estimate = coefficients[, "Estimate"],
    std_error = coefficients[, "Std. Error"],
    statistic = coefficients[, 3],
    p_value = coefficients[, 4],
    stringsAsFactors = FALSE
  )
  out$lower <- out$estimate - 1.96 * out$std_error
  out$upper <- out$estimate + 1.96 * out$std_error

  # The intercept is the baseline log-odds, not an effect, and plotting it
  # alongside the others compresses them against its scale.
  out <- out[out$variable != "(Intercept)", ]
  rownames(out) <- NULL
  out[order(-abs(out$estimate)), ]
}

#' Plot logistic regression coefficients with their intervals
#'
#' @param coefficients a data frame from [glm_coefficients()]
#' @param path optional file to write the plot to instead of returning it
#' @return a `ggplot` object, or `path` invisibly when writing
#' @export
plot_glm_coefficients <- function(coefficients, path = NULL) {
  if (nrow(coefficients) == 0) stop("No coefficients to plot.", call. = FALSE)

  coefficients$variable <- factor(coefficients$variable,
                                   levels = rev(coefficients$variable))

  p <- ggplot2::ggplot(coefficients,
                        ggplot2::aes(x = .data$estimate, y = .data$variable)) +
    # Zero is the reference the intervals are read against: an interval
    # crossing it is a predictor the model cannot sign.
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50") +
    ggplot2::geom_errorbar(ggplot2::aes(xmin = .data$lower, xmax = .data$upper),
                           orientation = "y", width = 0.25, colour = "#2c7fb8") +
    ggplot2::geom_point(size = 2, colour = "#2c7fb8") +
    ggplot2::labs(x = "Log-odds per standard deviation", y = NULL) +
    ggplot2::theme_minimal()

  if (is.null(path)) return(p)
  ggplot2::ggsave(path, plot = p, width = 7,
                  height = max(2.5, 0.35 * nrow(coefficients) + 1.5), dpi = 150)
  invisible(path)
}

#' The underlying engine object from a fitted model
#'
#' The `ranger`, `xgb.Booster`, `glm`, or `gam` object inside the workflow,
#' rather than the workflow wrapping it. Anything that plots or interrogates a
#' model directly needs this rather than the tidymodels object — including
#' [fancygam](https://github.com/chross22/fancygam), whose `plotSmooths()` takes
#' an `mgcv` fit, which is what this returns for `model.type: gam`.
#'
#' @param model a fitted model from [fit_patch_model()], or a fitted workflow
#' @return the engine's own fitted object
#' @examples
#' \dontrun{
#' # Prettier smooths than the generic partial effects can give:
#' fancygam::plotSmooths(model_engine_fit(model))
#' }
#' @export
model_engine_fit <- function(model) {
  workflow <- if (inherits(model, "workflow")) model else model$workflow
  workflows::extract_fit_engine(workflow)
}

#' Smooth terms of a fitted GAM
#'
#' What a GAM has that the others do not: a per-term statement of how non-linear
#' the fitted relationship actually is. `edf` is the effective degrees of freedom
#' — 1 means the smooth collapsed to a straight line and the flexibility bought
#' nothing, and larger values mean a genuinely bending relationship.
#'
#' @param fitted a fitted `workflows::workflow()` whose model is an `mgcv` GAM
#' @return a data frame of `term`, `edf`, `statistic`, and `p_value`, most
#'   non-linear first
#' @examples
#' \dontrun{
#' gam_smooth_terms(model$workflow)
#' }
#' @export
gam_smooth_terms <- function(fitted) {
  engine <- model_engine_fit(fitted)
  smooths <- summary(engine)$s.table

  if (is.null(smooths) || nrow(smooths) == 0) {
    return(data.frame(term = character(), edf = numeric(), statistic = numeric(),
                      p_value = numeric(), stringsAsFactors = FALSE))
  }

  out <- data.frame(
    term = rownames(smooths),
    edf = smooths[, "edf"],
    statistic = smooths[, "Chi.sq"],
    p_value = smooths[, "p-value"],
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL
  out[order(-out$edf), ]
}

#' Whether fancygam is available to draw smooths
#'
#' Its own function so the optional path can be exercised in tests without
#' mocking `requireNamespace()` itself, which every package that loads a
#' graphics device also goes through.
#'
#' @return `TRUE` when fancygam is installed
#' @keywords internal
has_fancygam <- function() {
  requireNamespace("fancygam", quietly = TRUE)
}

#' Variables a fitted GAM gave a smooth to
#'
#' Not every predictor gets one — [model_formula()] gives a linear term to any
#' predictor with too few distinct values to identify a smooth — so this reads
#' back what the fitted model actually did rather than assuming.
#'
#' @param fitted a fitted `workflows::workflow()` whose model is an `mgcv` GAM
#' @return character vector of variable names, in the model's own order
#' @keywords internal
gam_smoothed_variables <- function(fitted) {
  terms <- rownames(summary(model_engine_fit(fitted))$s.table)
  if (is.null(terms)) return(character())
  # "s(SST)" -> "SST"
  sub("^s\\((.*)\\)$", "\\1", terms)
}

#' Plot a GAM's fitted smooths, with fancygam
#'
#' The partial effect of each smooth term on the log-odds scale, with its
#' standard error band and a rug showing where the data actually is. This is the
#' exact version of [partial_effects()] for a GAM: read out of the fitted model
#' rather than reconstructed by prediction, so it carries uncertainty, which a
#' partial dependence curve cannot.
#'
#' Drawn by [fancygam](https://github.com/chross22/fancygam), which is a Suggests
#' — a run without it still gets the generic partial effect curves.
#'
#' @section Why the axes read in standard deviations:
#' The smooths belong to the model, and the model was fitted on the recipe's
#' output — so `x` is whatever the recipe made of the predictor. With the default
#' `covariates.normalize: true` that is standard deviations from the mean, and
#' the rug is taken from the same baked data so the two line up. Set
#' `covariates.normalize: false` to have these read in the covariate's own units;
#' it costs a tree model nothing, and a GAM little.
#'
#' @param model a fitted model from [fit_patch_model()]
#' @param vars which smooths to draw; `NULL` uses all of them
#' @param path optional file to write the plot to instead of returning it
#' @return a `patchwork`/`ggplot` object, or `path` invisibly when writing
#' @examples
#' \dontrun{
#' plot_gam_smooths(model)
#' }
#' @seealso [gam_smooth_terms()] for the numbers behind these
#' @export
plot_gam_smooths <- function(model, vars = NULL, path = NULL) {
  if (!has_fancygam()) {
    stop("The 'fancygam' package is required to plot GAM smooths. ",
         "Install it with remotes::install_github('chross22/fancygam').",
         call. = FALSE)
  }
  workflow <- if (inherits(model, "workflow")) model else model$workflow

  vars <- vars %||% gam_smoothed_variables(workflow)
  if (length(vars) == 0) {
    stop("This model has no smooth terms to plot.", call. = FALSE)
  }

  # The engine was fitted on the recipe's output, so gratia reports the smooths
  # in those units. The rug has to come from the same baked frame or the two
  # would be drawn on different x scales and quietly disagree.
  baked <- as.data.frame(workflows::extract_mold(workflow)$predictors)

  plot <- fancygam::combinePlots(model_engine_fit(workflow), baked, vars)

  if (is.null(path)) return(plot)
  ggplot2::ggsave(path, plot = plot, dpi = 150,
                  width = max(7, 4 * min(length(vars), 2)),
                  height = max(4, 3.2 * ceiling(length(vars) / 2)))
  invisible(path)
}

#' Model-specific diagnostics for a fitted model
#'
#' Partial effects for every type, since the question "what does this predictor
#' do" is the same question whichever model answered it. Then the one thing the
#' chosen model can say that the others cannot: signed coefficients for a GLM,
#' effective degrees of freedom per smooth for a GAM. A forest and a boosted
#' ensemble have no such summary — their answer *is* the partial effect curve,
#' which is why that one is computed for all four rather than only where an
#' engine happens to report something.
#'
#' @param model a fitted model from [fit_patch_model()]
#' @param out the run's diagnostics directory
#' @return character vector of paths written, invisibly
#' @keywords internal
write_effect_plots <- function(model, out) {
  written <- character()

  # Warned rather than swallowed. A diagnostic that silently produces nothing
  # is indistinguishable from one that was never asked for, and the run is
  # otherwise complete - so this should not abort it, but it must be visible.
  effects <- try_diagnostic(
    partial_effects(model$workflow, model$model_data, model$predictors),
    "partial effects"
  )
  if (!is.null(effects) && nrow(effects) > 0) {
    readr::write_csv(effects, file.path(out, "partial_effects.csv"))
    plot_partial_effects(effects, file.path(out, "partial_effects.png"))
    written <- c(written, "partial_effects.png")
  }

  if (identical(model$type, "glm")) {
    coefficients <- try_diagnostic(glm_coefficients(model$workflow),
                                   "GLM coefficients")
    if (!is.null(coefficients) && nrow(coefficients) > 0) {
      readr::write_csv(coefficients, file.path(out, "coefficients.csv"))
      plot_glm_coefficients(coefficients, file.path(out, "coefficients.png"))
      written <- c(written, "coefficients.png")
    }
  }

  if (identical(model$type, "gam")) {
    terms <- try_diagnostic(gam_smooth_terms(model$workflow), "GAM smooth terms")
    if (!is.null(terms) && nrow(terms) > 0) {
      readr::write_csv(terms, file.path(out, "smooth_terms.csv"))
      written <- c(written, "smooth_terms.csv")
    }

    # The fitted smooths themselves, with their uncertainty. Skipped without a
    # word when fancygam is absent: it is a Suggests, and the generic partial
    # effect curves above already cover the question.
    if (has_fancygam()) {
      smooths <- try_diagnostic(
        plot_gam_smooths(model, path = file.path(out, "gam_smooths.png")),
        "GAM smooth plots"
      )
      if (!is.null(smooths)) written <- c(written, "gam_smooths.png")
    }
  }

  invisible(written)
}

#' Run a diagnostic, warning rather than failing the run
#'
#' The model is already fitted and its outputs already written by this point, so
#' a diagnostic that cannot be produced should not throw the run away. It should
#' also not pass silently: an empty diagnostics directory looks the same whether
#' the plot failed or was never wanted.
#'
#' @param expr the diagnostic to attempt
#' @param what its name, for the warning
#' @return the result, or `NULL` with a warning
#' @keywords internal
try_diagnostic <- function(expr, what) {
  tryCatch(expr, error = function(e) {
    warning("Could not produce ", what, ": ", conditionMessage(e), call. = FALSE)
    NULL
  })
}
