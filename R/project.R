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
#' @section Getting the numbers out:
#' Each month is a GeoTIFF, which carries its own coordinates and is what a GIS
#' wants. Alongside them goes one `suitability.csv` for the whole run, in long
#' form: species, year, month, longitude, latitude, probability. That is the one
#' to read into anything that is not a GIS, and it is written a month at a time
#' rather than accumulated, since a decade of a real grid is tens of millions of
#' rows. Set `projection.write_csv` to `false` to skip it.
#'
#' Setting `projection.write_grd` to `true` also writes one multi-layer raster
#' holding every month, layer names carrying the dates. See
#' [write_suitability_stack()].
#'
#' @return a tibble with `year`, `month`, `n_cells` (predicted), `n_grid` (cells
#'   available), `resolution` in degrees, and the `geotiff`/`png` paths written.
#'   The suitability table's path is on it as a `table` attribute.
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

  uncertainty <- uncertainty_settings(config)
  if (!is.null(uncertainty)) {
    members <- length(model$ensemble)
    message("  uncertainty on: ", members, "-member ", uncertainty$method,
            " ensemble, ", round(100 * uncertainty$level), "% interval",
            if (isTRUE(uncertainty$novelty)) ", plus a novelty surface" else "")
    if (members < 2) {
      warning("projection.uncertainty is on, but the ensemble has ", members,
              " member(s), so no interval can be computed. The maps are ",
              "written without one.", call. = FALSE)
    }
  }

  # Written a month at a time rather than gathered and written at the end. A
  # decade of a real grid is tens of millions of rows, which is fine on disk and
  # not fine held in memory while the rest of the run finishes.
  table_path <- file.path(proj_dir, "suitability.csv")
  write_table <- !isFALSE(config$projection$write_csv)
  if (write_table) unlink(table_path)
  first_row <- TRUE

  results <- list()
  for (year in years) {
    for (month in months) {
      grid <- covariate_grid(env_dat, year, month, config)
      if (is.null(grid)) next
      if (!is.null(bathy)) {
        grid <- datamatch::attach_bathymetry(grid, bathy, config$covariates$bathymetry)
      }

      predicted <- predict_grid(model, grid, uncertainty)
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

      # A cell outside the training range is one the model has no evidence
      # about, and an unremarked map does not say so. Reported per month,
      # because it is the projected months at the edges of the record that
      # usually drift out.
      extra <- uncertainty_layers(predicted)
      if ("novelty" %in% extra) {
        note <- novelty_message(predicted$novelty, predicted$novel_variable)
        if (!is.null(note)) {
          message("  ", year, "-", sprintf("%02d", month), ": ", note)
        }
      }

      # One raster with a layer per surface when uncertainty is on, rather than
      # a second file beside the first: they are the same cells on the same
      # grid, and a GIS reading the tif gets the interval along with the mean
      # instead of having to know to look for it.
      rast <- terra::rast(
        as.data.frame(predicted[c("lon", "lat", "suitability", extra)]),
        type = "xyz", crs = "EPSG:4326"
      )
      names(rast) <- c("suitability", extra)

      if (isTRUE(config$projection$write_geotiff)) {
        geotiff_path <- file.path(proj_dir, paste0(stem, ".tif"))
        if (!file.exists(geotiff_path) || isTRUE(config$projection$overwrite)) {
          terra::writeRaster(rast, geotiff_path, overwrite = TRUE)
        }
      }
      if (isTRUE(config$projection$write_png)) {
        png_path <- file.path(plot_dir, paste0(stem, ".png"))
        plot_projection(predicted, year, month, species, png_path)

        # Beside the suitability map rather than on it. Drawing an interval on
        # a filled surface means picking something to hide, and the question
        # "where is the patch" and the question "where should I believe this"
        # are read one after the other rather than at once.
        if (length(extra) > 0) {
          plot_projection_uncertainty(predicted, year, month, species,
                                      file.path(plot_dir,
                                                paste0(stem, "_uncertainty.png")))
        }
      }

      if (write_table) {
        # Long rather than one column per month: a month is a value here, not a
        # variable, and a wide table would have to be reshaped by anything
        # reading it back.
        rows <- data.frame(
          species = species, year = year, month = month,
          lon = predicted$lon, lat = predicted$lat,
          suitability = predicted$suitability,
          stringsAsFactors = FALSE
        )
        for (layer in extra) rows[[layer]] <- predicted[[layer]]
        if ("novelty" %in% extra) rows$novel_variable <- predicted$novel_variable

        readr::write_csv(rows, table_path, append = !first_row,
                         col_names = first_row)
        first_row <- FALSE
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
  out <- dplyr::bind_rows(results)
  if (write_table && file.exists(table_path)) {
    message("  suitability table written to ", table_path)
    attr(out, "table") <- table_path
  }

  # Off by default: it is the same numbers as the GeoTIFFs in another container,
  # and writing both on every run doubles the output for a format most runs do
  # not need.
  if (isTRUE(config$projection$write_grd)) {
    stack_path <- file.path(proj_dir, "suitability.grd")
    written <- tryCatch(write_suitability_stack(out, stack_path),
                        error = function(e) {
                          warning("Could not write the raster stack: ",
                                  conditionMessage(e), call. = FALSE)
                          NULL
                        })
    if (!is.null(written)) {
      message("  raster stack written to ", stack_path)
      attr(out, "stack") <- stack_path
    }
  }
  out
}

#' Predict patch probability across a covariate grid
#'
#' Rows with missing predictors are dropped before predicting rather than
#' predicted and discarded, since the recipe's `step_naomit()` is skipped at bake
#' time and would otherwise yield NA probabilities.
#'
#' @param model a fitted model from `fit_patch_model()`
#' @param grid a covariate grid from `covariate_grid()`
#' @param uncertainty settings from [uncertainty_settings()], or `NULL` for the
#'   point estimate alone
#' @return a tibble of `lon`, `lat`, `suitability`, and, with `uncertainty`, the
#'   spread and novelty columns; `NULL` if no complete rows
#' @keywords internal
predict_grid <- function(model, grid, uncertainty = NULL) {
  complete <- grid[stats::complete.cases(grid[model$predictors]), ]
  if (nrow(complete) == 0) return(NULL)

  probs <- stats::predict(model$workflow, new_data = complete, type = "prob")
  out <- tibble::tibble(
    lon = complete$lon,
    lat = complete$lat,
    suitability = probs$.pred_patch
  )
  if (is.null(uncertainty)) return(out)

  spread <- ensemble_spread(model$ensemble, complete, uncertainty$level)
  if (!is.null(spread)) out <- dplyr::bind_cols(out, spread)

  if (isTRUE(uncertainty$novelty)) {
    out <- dplyr::bind_cols(
      out, novelty_surface(complete, model$model_data, model$predictors)
    )
  }
  out
}

#' Uncertainty layers present on a projection
#'
#' Which of the optional columns [predict_grid()] actually produced. The
#' ensemble can come back empty — a model type that refuses to refit on a
#' resample, say — and a map is written either way rather than the run failing
#' at the last step.
#'
#' @param predicted a projection from [predict_grid()]
#' @return character vector of column names beyond `suitability`
#' @keywords internal
uncertainty_layers <- function(predicted) {
  intersect(c("suitability_sd", "suitability_lower", "suitability_upper",
              "novelty"),
            names(predicted))
}

#' Write the monthly projections as one multi-layer raster
#'
#' The per-month GeoTIFFs are one file each, which is what a GIS wants and
#' awkward for anything that treats time as a dimension: a decade is a hundred
#' and eighty files whose only record of which month they are is the filename.
#' This stacks them into a single raster with one layer per month, named for it.
#'
#' Built from the files rather than from rasters held in memory. `terra` reads a
#' stack lazily, so a decade of a real grid is streamed from disk to disk instead
#' of being assembled in one piece first.
#'
#' @section Why .grd:
#' It is `raster`'s native format and `terra` writes it, it keeps layer names -
#' which is the whole point here, since the names carry the dates - and it has no
#' band limit. GeoTIFF can hold the layers but not their names, so a stacked
#' `.tif` would come back as `suitability_1` through `suitability_180`. Note that
#' it is two files: a `.grd` header and a `.gri` of data, and one is no use
#' without the other.
#'
#' One wrinkle worth knowing. `terra` writes a `.grd` header without recording
#' each layer's range, so `terra::minmax()` on the result reports a placeholder
#' of some 1e38 rather than the 0 to 1 a probability actually spans. The values
#' are correct - they match the GeoTIFFs cell for cell - and
#' `terra::global(stack, range, na.rm = TRUE)` gives the real range. Only a
#' reader that trusts the header, such as an automatic colour scale, is misled,
#' and setting the range yourself is the fix there.
#'
#' @param projections the tibble [project_patch_model()] returns
#' @param path where to write the `.grd`
#' @return `path`, invisibly
#' @examples
#' \dontrun{
#' write_suitability_stack(result$projections, "suitability.grd")
#' }
#' @export
write_suitability_stack <- function(projections, path) {
  available <- projections[!is.na(projections$geotiff) &
                             file.exists(projections$geotiff), ]
  if (nrow(available) == 0) {
    stop("No GeoTIFFs to stack. A run with projection.write_geotiff set to ",
         "false has nothing to build this from.", call. = FALSE)
  }

  stack <- terra::rast(available$geotiff)
  # The dates are the reason for stacking, so they have to survive as names.
  names(stack) <- sprintf("%d_%02d", available$year, available$month)
  terra::time(stack) <- as.Date(sprintf("%d-%02d-15", available$year,
                                        available$month))

  terra::writeRaster(stack, path, overwrite = TRUE)
  invisible(path)
}
