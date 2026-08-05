#' Project a fitted model to monthly habitat suitability maps
#'
#' Predicts patch probability across the covariate grid for every configured
#' month and year. One pooled model produces month-specific maps because
#' day-of-year is a predictor and the covariates themselves are monthly — the same
#' arrangement as `original/buildZoopModel.R`, without the `raster`/`/1000`/manual
#' CRS-string handling it needed to read biomod2's output back off disk.
#'
#' @param model a fitted model from `fit_patch_model()`
#' @param env_dat covariate data from `fetch_covariates()`
#' @param config a config list, as returned by `load_config()`
#' @param bathy optional static bathymetry `SpatRaster` from `fetch_bathymetry()`,
#'   attached to every month since it does not vary in time
#' @return a tibble with `year`, `month`, `n_cells`, and the `geotiff`/`png` paths
#'   written for each projection
#' @export
project_patch_model <- function(model, env_dat, config, bathy = NULL) {
  proj_dir <- file.path(config$paths$output_dir, "projections")
  plot_dir <- file.path(config$paths$output_dir, "plots")
  dir.create(proj_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)

  # Projection runs over its own window, which need not be the window the model
  # was trained on - fitting on a long history and projecting a recent or future
  # period is the normal case.
  years <- seq(config$projection$years[1], config$projection$years[2])
  months <- seq(config$projection$months[1], config$projection$months[2])
  species <- config$species$resolved$name

  results <- list()
  for (year in years) {
    for (month in months) {
      grid <- covariate_grid(env_dat, year, month, config)
      if (is.null(grid)) next
      if (!is.null(bathy)) {
        grid <- attach_bathymetry(grid, bathy, config$covariates$bathymetry)
      }

      predicted <- predict_grid(model, grid)
      if (is.null(predicted)) next

      stem <- sprintf("%s_%d_%02d", species, year, month)
      geotiff_path <- NA_character_
      png_path <- NA_character_

      rast <- terra::rast(
        as.data.frame(predicted[c("lon", "lat", "suitability")]),
        type = "xyz", crs = "EPSG:4326"
      )

      if (isTRUE(config$projection$write_geotiff)) {
        geotiff_path <- file.path(proj_dir, paste0(stem, ".tif"))
        if (!file.exists(geotiff_path) || isTRUE(config$projection$overwrite)) {
          terra::writeRaster(rast, geotiff_path, overwrite = TRUE)
        }
      }
      if (isTRUE(config$projection$write_png)) {
        png_path <- file.path(plot_dir, paste0(stem, ".png"))
        plot_projection(predicted, year, month, species, png_path)
      }

      results[[length(results) + 1]] <- tibble::tibble(
        year = year, month = month, n_cells = nrow(predicted),
        geotiff = geotiff_path, png = png_path
      )
    }
  }

  if (length(results) == 0) {
    stop("No projections produced: the covariate data covers none of the configured ",
         "year/month combinations.", call. = FALSE)
  }
  dplyr::bind_rows(results)
}

#' Predict patch probability across a covariate grid
#'
#' Rows with missing predictors are dropped before predicting rather than
#' predicted and discarded, since the recipe's `step_naomit()` is skipped at bake
#' time and would otherwise yield NA probabilities.
#'
#' @param model a fitted model from `fit_patch_model()`
#' @param grid a covariate grid from `covariate_grid()`
#' @return a tibble of `lon`, `lat`, `suitability`, or `NULL` if no complete rows
#' @keywords internal
predict_grid <- function(model, grid) {
  complete <- grid[stats::complete.cases(grid[model$predictors]), ]
  if (nrow(complete) == 0) return(NULL)

  probs <- stats::predict(model$workflow, new_data = complete, type = "prob")
  tibble::tibble(
    lon = complete$lon,
    lat = complete$lat,
    suitability = probs$.pred_patch
  )
}
