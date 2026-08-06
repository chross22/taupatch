#' Run the full taupatch pipeline
#'
#' Loads a config and runs every stage in order: read zooplankton stations, fetch
#' and attach environmental covariates, label high-abundance patches against the
#' species threshold, fit the model, and project monthly habitat suitability maps.
#'
#' @param config_path path to a config YAML file, or an already-loaded config list
#' @param project whether to produce monthly projections after fitting
#' @param keep_covariates the most covariate grid cells to return for mapping;
#'   `0` returns none. See [thin_covariates()] for what is kept and why.
#' @return a list with `config`, `data` (the labeled modeling data), `model` (the
#'   `fit_patch_model()` result), `projections` (or `NULL` if skipped),
#'   `covariate_means`, and `covariates` (a thinned grid, for mapping)
#' @examples
#' \dontrun{
#' result <- run_taupatch(system.file("configs/mock_test.yaml", package = "taupatch"))
#' result$model$metrics
#' result$projections
#' }
#' @export
run_taupatch <- function(config_path, project = TRUE, keep_covariates = 50000) {
  config <- if (is.list(config_path)) config_path else load_config(config_path)
  dir.create(config$paths$output_dir, recursive = TRUE, showWarnings = FALSE)

  message("Loading zooplankton data...")
  dat <- load_zoop_data(config)
  message("  ", nrow(dat), " station records")

  message("Fetching environmental covariates (", config$covariates$source, ")...")
  env_dat <- fetch_covariates(config)

  bathy <- NULL
  if (length(config$covariates$bathymetry) > 0) {
    message("Fetching bathymetry (NOAA ETOPO)...")
    bathy <- study_area_bathymetry(config)
  }

  # Derived covariates are computed on the grid, before stations are matched to
  # it: a gradient or a front is a property of the field, and scattered station
  # points cannot recover one. Everything after this treats them as ordinary
  # covariate columns.
  if (length(config$covariates$derivoce) > 0) {
    message("Deriving covariates (derivoce)...")
    env_dat <- add_derivoce_covariates(env_dat, config, bathy = bathy)
  }

  # Summarized now rather than returning the whole grid, which for a real
  # Copernicus fetch is millions of points.
  covariate_means <- covariate_monthly_means(env_dat)

  message("Matching covariates to stations...")
  dat <- attach_covariates(dat, env_dat, config)
  dat <- add_derived_covariates(dat, config)
  if (length(config$covariates$climate) > 0) {
    message("Attaching climate indices (", paste(config$covariates$climate,
                                                 collapse = ", "), ")...")
    dat <- attach_climate_indices(dat, config)
  }
  if (!is.null(bathy)) {
    dat <- datamatch::attach_bathymetry(dat, bathy, config$covariates$bathymetry)
    # Stations on land or outside the bathymetry grid get NA depth; they cannot
    # be modeled and would otherwise be dropped silently inside the recipe.
    before <- nrow(dat)
    dat <- drop_missing(dat, config$covariates$bathymetry)
    if (nrow(dat) < before) {
      message("  dropped ", before - nrow(dat), " records with no bathymetry")
    }
  }
  message("  ", nrow(dat), " records with complete covariates")

  message("Labeling patches...")
  dat <- label_patch(dat, config)
  message("  threshold: ", signif(attr(dat, "threshold"), 6),
          " (", sum(dat$patch == "patch"), " patch / ",
          sum(dat$patch == "non_patch"), " non-patch)")

  message("Fitting model...")
  model <- fit_patch_model(dat, config)
  write_model_outputs(model, config)
  write_covariate_summary(covariate_means, config)
  message("  ROC AUC: ", signif(model$metrics$mean[model$metrics$.metric == "roc_auc"], 4))

  projections <- NULL
  if (project) {
    message("Projecting monthly suitability...")
    projections <- project_patch_model(model, env_dat, config, bathy = bathy)
    message("  ", nrow(projections), " monthly projections written")
  }

  message("Output written to ", config$paths$output_dir)
  list(config = config, data = dat, model = model, projections = projections,
       covariate_means = covariate_means,
       # A thinned copy, for looking at rather than modelling. The full grid is
       # millions of points on a real fetch, and a map of every one of them
       # would be a map of a subsample anyway once it hit the screen.
       covariates = if (keep_covariates > 0) {
         thin_covariates(env_dat, keep_covariates)
       })
}

#' Write model artifacts to the output directory
#'
#' The same artifacts the original pipeline produced (evaluations, variable
#' importance, the fitted model), without biomod2's nested directory layout.
#'
#' @param model a fitted model from `fit_patch_model()`
#' @param config a config list, as returned by `load_config()`
#' @return `NULL`, invisibly
#' @keywords internal
write_model_outputs <- function(model, config) {
  out <- config$paths$output_dir
  dir.create(out, recursive = TRUE, showWarnings = FALSE)

  saveRDS(model$workflow, file.path(out, "model.rds"))
  # evals.csv states the cutoff each metric belongs to, and reports the
  # threshold-dependent ones at both 0.5 and the TSS-optimal cutoff. The raw
  # resampling table is kept alongside for anything that wants the per-fold
  # structure.
  readr::write_csv(model$evaluation, file.path(out, "evals.csv"))
  readr::write_csv(model$metrics, file.path(out, "cv_metrics.csv"))
  readr::write_csv(model$importance, file.path(out, "var_importance.csv"))
  plot_importance(model$importance, file.path(out, "var_importance.png"))
  write_diagnostic_plots(model, out)

  # Record the computed threshold alongside the run, so a percentile-based run is
  # reproducible as an absolute one. The original wrote this back into the config
  # file itself, mutating the run's own inputs.
  writeLines(
    paste0("species: ", config$species$resolved$name, "\n",
           "threshold_type: ", config$species$resolved$threshold$type, "\n",
           "threshold_value: ", config$species$resolved$threshold$value, "\n",
           "threshold_computed: ", model$threshold, "\n",
           "# Probability cutoff maximising TSS on held-out folds. The metrics\n",
           "# in evals.csv are at the default 0.5, which is rarely optimal when\n",
           "# only a tenth of stations are patches.\n",
           "classification_threshold: ", model$classification_threshold),
    file.path(out, "threshold.yaml")
  )
  invisible(NULL)
}

#' Write model diagnostic plots
#'
#' All four are drawn from held-out cross-validation predictions, so they describe
#' performance on data the model did not see. The predictions themselves are saved
#' alongside, so a diagnostic not covered here can be produced without refitting.
#'
#' Alongside them go the effect plots, which depend on which model was fitted:
#' partial effects for every type, plus coefficients for a GLM or smooth terms
#' for a GAM. See `write_effect_plots()`.
#'
#' @param model a fitted model from `fit_patch_model()`
#' @param out the run's output directory
#' @return `NULL`, invisibly
#' @keywords internal
write_diagnostic_plots <- function(model, out) {
  predictions <- model$predictions
  if (is.null(predictions) || nrow(predictions) == 0) return(invisible(NULL))

  diagnostics <- file.path(out, "diagnostics")
  dir.create(diagnostics, recursive = TRUE, showWarnings = FALSE)

  readr::write_csv(predictions, file.path(diagnostics, "cv_predictions.csv"))
  plot_roc_curve(predictions, file.path(diagnostics, "roc_curve.png"))
  plot_pr_curve(predictions, file.path(diagnostics, "pr_curve.png"))
  plot_calibration(predictions, path = file.path(diagnostics, "calibration.png"))
  plot_threshold_performance(predictions,
                             file.path(diagnostics, "threshold_performance.png"))

  write_effect_plots(model, diagnostics)
  invisible(NULL)
}

#' Write covariate summaries and month-by-year heatmaps
#'
#' @param covariate_means a data frame from `covariate_monthly_means()`
#' @param config a config list, as returned by `load_config()`
#' @return `NULL`, invisibly
#' @keywords internal
write_covariate_summary <- function(covariate_means, config) {
  out <- file.path(config$paths$output_dir, "covariates")
  dir.create(out, recursive = TRUE, showWarnings = FALSE)

  readr::write_csv(covariate_means, file.path(out, "monthly_means.csv"))
  for (covariate in unique(covariate_means$covariate)) {
    plot_covariate_heatmap(covariate_means, covariate,
                           file.path(out, paste0(covariate, "_heatmap.png")))
  }
  invisible(NULL)
}
