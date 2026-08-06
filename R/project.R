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
#' @section What it projects onto:
#' Every cell of the covariate grid for that month, not the station locations.
#' Stations are used to fit the model and play no part here. The grid's
#' resolution is the one the covariates were joined onto, which
#' `covariates.grid` decides and any `covariates.prejoin` resampling can change,
#' so projecting finer means changing those rather than anything in this block.
#'
#' Cells missing any predictor are dropped, and the count is reported per month
#' along with the predictor most often responsible. That is usually a
#' neighbourhood step, which is undefined on the study-area border, or a lag,
#' which is undefined in the first month of the record.
#'
#' @return a tibble with `year`, `month`, `n_cells` (predicted), `n_grid` (cells
#'   available), `resolution` in degrees, and the `geotiff`/`png` paths written
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

  # The projection lands on whatever grid the join produced, which is a
  # consequence of `covariates.grid` and of any prejoin resampling rather than a
  # projection setting. Stated up front, because a map's resolution is otherwise
  # only discoverable by opening the GeoTIFF.
  resolution <- grid_spacing(env_dat)
  message("  projecting onto a ", signif(resolution, 3), " degree grid (~",
          round(resolution * 111), " km), the grid the covariates were joined ",
          "onto")

  results <- list()
  for (year in years) {
    for (month in months) {
      grid <- covariate_grid(env_dat, year, month, config)
      if (is.null(grid)) next
      if (!is.null(bathy)) {
        grid <- datamatch::attach_bathymetry(grid, bathy, config$covariates$bathymetry)
      }

      predicted <- predict_grid(model, grid)
      # A cell is dropped when any predictor is missing there. With a gradient or
      # a front among them that is the whole border of the study area, and with a
      # lag it is the first month - neither of which is obvious from the map.
      dropped <- nrow(grid) - (if (is.null(predicted)) 0 else nrow(predicted))
      if (dropped > 0 && !is.null(predicted)) {
        incomplete <- vapply(model$predictors, function(v) {
          sum(is.na(grid[[v]]))
        }, integer(1))
        # Every predictor with gaps, not just the worst one. Which covariate is
        # punching the holes is the only thing worth knowing here, and guessing
        # at the cause from the shape of the map is how the wrong covariate gets
        # blamed.
        culprits <- sort(incomplete[incomplete > 0], decreasing = TRUE)
        message("  ", year, "-", sprintf("%02d", month), ": ", dropped, " of ",
                nrow(grid), " cells dropped (",
                round(100 * dropped / nrow(grid)), "% of the grid)")
        message("    missing per predictor: ",
                paste0(names(culprits), " ", culprits,
                       " (", round(100 * culprits / nrow(grid)), "%)",
                       collapse = ", "))
      }
      if (is.null(predicted)) {
        # Normal for the first month of the record once a lag, integral, or
        # temporal gradient is configured: those are undefined there, so no cell
        # has a complete predictor set. Said out loud rather than skipped
        # silently, since the alternative cause is a covariate that failed to
        # fetch for that month.
        message("  no complete cells for ", year, "-", sprintf("%02d", month),
                "; skipped")
        next
      }

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
        n_grid = nrow(grid), resolution = resolution,
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
