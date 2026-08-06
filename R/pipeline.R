#' Run the full taupatch pipeline
#'
#' Loads a config and runs every stage in order: read zooplankton stations, fetch
#' and attach environmental covariates, label high-abundance patches against the
#' species threshold, fit the model, and project monthly habitat suitability maps.
#'
#' @param config_path path to a config YAML file, or an already-loaded config list
#' @param project whether to produce monthly projections after fitting
#' @return a list with `config`, `data` (the labeled modeling data), `model` (the
#'   `fit_patch_model()` result), and `projections` (or `NULL` if skipped)
#' @examples
#' \dontrun{
#' result <- run_taupatch(system.file("configs/mock_test.yaml", package = "taupatch"))
#' result$model$metrics
#' result$projections
#' }
#' @export
run_taupatch <- function(config_path, project = TRUE) {
  config <- if (is.list(config_path)) config_path else load_config(config_path)
  dir.create(config$paths$output_dir, recursive = TRUE, showWarnings = FALSE)

  message("Loading zooplankton data...")
  dat <- load_zoop_data(config)
  message("  ", nrow(dat), " station records")

  message("Fetching environmental covariates (", config$covariates$source, ")...")
  env_dat <- fetch_covariates(config)

  # Summarized now rather than returning the whole grid, which for a real
  # Copernicus fetch is millions of points.
  covariate_means <- covariate_monthly_means(env_dat)

  bathy <- NULL
  if (length(config$covariates$bathymetry) > 0) {
    message("Fetching bathymetry (NOAA ETOPO)...")
    bathy <- study_area_bathymetry(config)
  }

  message("Matching covariates to stations...")
  dat <- attach_covariates(dat, env_dat, config)
  dat <- add_derived_covariates(dat, config)
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
       covariate_means = covariate_means)
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
  readr::write_csv(model$metrics, file.path(out, "evals.csv"))
  readr::write_csv(model$importance, file.path(out, "var_importance.csv"))
  plot_importance(model$importance, file.path(out, "var_importance.png"))

  # Record the computed threshold alongside the run, so a percentile-based run is
  # reproducible as an absolute one. The original wrote this back into the config
  # file itself, mutating the run's own inputs.
  writeLines(
    paste0("species: ", config$species$resolved$name, "\n",
           "threshold_type: ", config$species$resolved$threshold$type, "\n",
           "threshold_value: ", config$species$resolved$threshold$value, "\n",
           "threshold_computed: ", model$threshold),
    file.path(out, "threshold.yaml")
  )
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
