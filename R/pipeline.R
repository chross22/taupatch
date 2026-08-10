#' Run the full taupatch pipeline
#'
#' Loads a config and runs every stage in order: read zooplankton stations, fetch
#' and attach environmental covariates, label high-abundance patches against the
#' species threshold, fit the model, and project monthly habitat suitability maps.
#'
#' Two optional stages sit between labelling and fitting, both off by default
#' and both turned on from the config:
#'
#' * `covariates.jackknife` tests each covariate by leaving it out — see
#'   [jackknife_settings()]. It runs before the fit so its answer can change
#'   which covariates the model gets, and it only removes any if
#'   `jackknife.drop` says so.
#' * `model.ensemble` fits several algorithms instead of one and combines them —
#'   see [ensemble_settings()]. Everything after the fit works the same either
#'   way, so a config that turns this on gets ensemble projections without
#'   changing anything else.
#'
#' @param config_path path to a config YAML file, or an already-loaded config list
#' @param project whether to produce monthly projections after fitting
#' @param keep_covariates the most covariate grid cells to return for mapping;
#'   `0` returns none. See [thin_covariates()] for what is kept and why.
#' @return a list with `config` (as the run actually used it, so a jackknife that
#'   dropped a covariate shows in `covariates.exclude`), `data` (the labeled
#'   modeling data), `model` (a [fit_patch_model()] result, or a
#'   [fit_patch_ensemble()] one), `projections` (or `NULL` if skipped),
#'   `jackknife` (or `NULL` if not run), `covariate_means`, and `covariates` (a
#'   thinned grid, for mapping)
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

  # Before fitting, not after: the point of testing covariates is to decide
  # which ones the model gets, and a test run against the final model would be
  # describing a model that has already been built.
  jackknife <- NULL
  jackknife_config <- jackknife_settings(config)
  if (!is.null(jackknife_config)) {
    message("Jackknifing covariates...")
    jackknife <- jackknife_covariates(dat, config, jackknife_config)
    report_jackknife(jackknife, jackknife_config)
    write_jackknife(jackknife, config)
    if (isTRUE(jackknife_config$drop)) {
      config <- apply_jackknife_drop(config,
                                     jackknife_dropped(jackknife, jackknife_config))
    }
  }

  message("Fitting model...")
  ensemble <- ensemble_settings(config)
  model <- if (is.null(ensemble)) {
    fit_patch_model(dat, config)
  } else {
    fit_patch_ensemble(dat, config, ensemble)
  }
  write_model_outputs(model, config)
  write_covariate_summary(covariate_means, config)
  # Read off the evaluation table rather than the metrics one, since that is
  # the table both a single model and an ensemble fill in the same way.
  message("  ROC AUC: ", signif(evaluation_value(model, "roc_auc"), 4))

  projections <- NULL
  if (project) {
    message("Projecting monthly suitability...")
    projections <- project_patch_model(model, env_dat, config, bathy = bathy)
    message("  ", nrow(projections), " monthly projections written")
  }

  message("Output written to ", config$paths$output_dir)
  list(config = config, data = dat, model = model, projections = projections,
       covariate_means = covariate_means, jackknife = jackknife,
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

  # An ensemble has no single workflow, so the whole object is what gets saved -
  # it holds every member's, and a projection needs all of them.
  saveRDS(model$workflow %||% model, file.path(out, "model.rds"))
  if (inherits(model, "taupatch_ensemble")) write_ensemble_outputs(model, out)
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
  # The cutoff is estimated from the same held-out predictions it is then used
  # to binarise, so how far it moves under resampling is part of what it means.
  # Omitted rather than faked when the bootstrap was turned off.
  interval <- model$classification_threshold_interval
  interval_lines <- if (is.null(interval)) {
    ""
  } else {
    paste0("\n# How far the cutoff itself moves across bootstrap resamples of\n",
           "# the held-out predictions. A wide range here means a binarised map\n",
           "# is sensitive to which stations happened to be sampled.\n",
           "classification_threshold_lower: ", interval[["lower"]], "\n",
           "classification_threshold_upper: ", interval[["upper"]])
  }

  writeLines(
    paste0("species: ", config$species$resolved$name, "\n",
           "threshold_type: ", config$species$resolved$threshold$type, "\n",
           "threshold_value: ", config$species$resolved$threshold$value, "\n",
           "threshold_computed: ", model$threshold, "\n",
           "# Probability cutoff maximising TSS on held-out folds. The metrics\n",
           "# in evals.csv are at the default 0.5, which is rarely optimal when\n",
           "# only a tenth of stations are patches.\n",
           "classification_threshold: ", model$classification_threshold,
           interval_lines),
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

  # An ensemble has no coefficients or smooths of its own; its members do, and
  # theirs are written into a directory each rather than averaged into
  # something no model actually fitted.
  if (inherits(model, "taupatch_ensemble")) {
    for (type in names(model$members)) {
      member_dir <- file.path(diagnostics, "members", type)
      dir.create(member_dir, recursive = TRUE, showWarnings = FALSE)
      write_effect_plots(model$members[[type]], member_dir)
    }
    return(invisible(NULL))
  }

  write_effect_plots(model, diagnostics)
  invisible(NULL)
}

#' Write an ensemble's own artifacts
#'
#' What a single model has no equivalent of: which algorithms were fitted, how
#' each scored, what weight it was given, and whether it qualified. This is the
#' first thing to read after an ensemble run — a table showing one member at
#' 0.9 weight and three near zero is a single model with extra steps, and only
#' this file says so.
#'
#' @param model a `taupatch_ensemble` from [fit_patch_ensemble()]
#' @param out the run's output directory
#' @return `NULL`, invisibly
#' @keywords internal
write_ensemble_outputs <- function(model, out) {
  readr::write_csv(model$summary, file.path(out, "ensemble_members.csv"))
  if (!is.null(model$member_metrics)) {
    readr::write_csv(model$member_metrics,
                     file.path(out, "member_cv_metrics.csv"))
  }
  invisible(NULL)
}

#' Write the covariate jackknife table
#'
#' Written whether or not anything was dropped, and written before the model is
#' fitted, so a run that turned `drop` on leaves a record of what it removed and
#' on what evidence.
#'
#' @param jk the result of [jackknife_covariates()]
#' @param config a config list, as returned by `load_config()`
#' @return `NULL`, invisibly
#' @keywords internal
write_jackknife <- function(jk, config) {
  out <- config$paths$output_dir
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(jk, file.path(out, "covariate_jackknife.csv"))
  invisible(NULL)
}

#' One metric's value from a model's evaluation table
#'
#' The threshold-free metrics live on the rows with no cutoff. Reading them from
#' here rather than from the resampling table is what lets a single model and an
#' ensemble be asked the same question — the ensemble's resampling table is one
#' per member, and its own performance is not the average of those.
#'
#' @param model a [fit_patch_model()] or [fit_patch_ensemble()] result
#' @param metric a threshold-free metric name
#' @return the value, or `NA_real_`
#' @keywords internal
evaluation_value <- function(model, metric = "roc_auc") {
  table <- model$evaluation
  if (is.null(table)) return(NA_real_)
  value <- table$value[table$metric == metric & is.na(table$threshold)]
  if (length(value) == 1) value else NA_real_
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

#' The stages a run passes through, and how far along each one is
#'
#' [run_taupatch()] announces each stage as it starts. This turns those
#' announcements into a position on a progress bar, so a caller watching a long
#' run can tell a covariate download from a model fit.
#'
#' The fractions are where a stage *begins*, and they are weighted by how long
#' each takes rather than spread evenly: fetching covariates is most of a real
#' run and labelling patches is instant, so an even split would sit at 40% for
#' twenty minutes and then race through the rest.
#'
#' Matched on the message rather than signalled through a condition class,
#' because the messages are the pipeline's existing interface to anyone watching
#' it and a second channel would be a second thing to keep in step.
#'
#' @return a data frame of `pattern`, `label`, and `at` (fraction complete when
#'   the stage starts), in order
#' @examples
#' pipeline_stages()
#' @export
pipeline_stages <- function() {
  data.frame(
    pattern = c(
      "^Loading zooplankton data",
      "^Fetching environmental covariates",
      "^Preparing covariates before the join",
      "^Fetching bathymetry",
      "^Deriving covariates",
      "^Matching covariates to stations",
      "^Attaching climate indices",
      "^Labeling patches",
      "^Jackknifing covariates",
      "^Fitting model",
      "^Projecting monthly suitability",
      "^Output written to"
    ),
    label = c(
      "Reading the station database",
      "Downloading covariates from Copernicus",
      "Resampling covariates before the join",
      "Downloading bathymetry",
      "Computing derived covariates",
      "Matching covariates to stations",
      "Attaching climate indices",
      "Labelling high-abundance patches",
      "Testing covariates by jackknife",
      "Fitting and cross-validating the model",
      "Projecting monthly maps",
      "Writing output"
    ),
    # The jackknife is the widest band after the download when it runs at all:
    # it is a full cross-validation per covariate, twice over.
    at = c(0.02, 0.06, 0.55, 0.60, 0.64, 0.72, 0.76, 0.78, 0.79, 0.86, 0.94,
           0.99),
    stringsAsFactors = FALSE
  )
}

#' Where a pipeline message places a run
#'
#' @param text a message from [run_taupatch()]
#' @return a one-row [pipeline_stages()] slice, or `NULL` for messages that are
#'   detail within a stage rather than the start of one
#' @keywords internal
match_pipeline_stage <- function(text) {
  stages <- pipeline_stages()
  hit <- which(vapply(stages$pattern, function(p) grepl(p, text), logical(1)))
  if (length(hit) == 0) return(NULL)
  stages[hit[1], ]
}
