#' Static seafloor covariates
#'
#' Bathymetry and the terrain measures derived from it. These are *static* — they
#' do not vary by month or year — so they are fetched once for the study area and
#' attached to every time step, unlike the Copernicus covariates.
#'
#' The original model used depth, slope, and distance to shore
#' (`original/load_covars.R` lines 98-104), sourced from SRTM30 files on a server
#' that no longer exists. They come from NOAA ETOPO via `marmap` now.
#'
#' @return a named list, one entry per covariate, each with `label`, `units`, and
#'   `description`
#' @examples
#' names(bathymetry_covariates())
#' @export
bathymetry_covariates <- function() {
  list(
    DEPTH = list(
      label = "Water depth", units = "m",
      description = paste("Seafloor depth from NOAA ETOPO, as a positive number",
                          "of metres. The original model log-transformed this,",
                          "since depth spans several orders of magnitude across",
                          "the shelf and slope.")
    ),
    SLOPE = list(
      label = "Bottom slope", units = "degrees",
      description = paste("Steepness of the seafloor, computed from the depth",
                          "grid. Picks out shelf breaks and canyon edges, where",
                          "zooplankton often aggregate.")
    ),
    ASPECT = list(
      label = "Bottom aspect", units = "degrees",
      description = paste("Compass direction the seafloor slope faces, computed",
                          "from the depth grid. Meaningless where the bottom is",
                          "flat, so expect noise in deep basins.")
    )
  )
}

#' Fetch static bathymetry covariates for the study area
#'
#' Downloads NOAA ETOPO bathymetry via `marmap::getNOAA.bathy()` and derives slope
#' and aspect from it.
#'
#' `marmap` caches downloads next to the working directory by default; this passes
#' `path` so the cache lands in the config's output directory instead, keeping a
#' run's downloads with the rest of its outputs.
#'
#' @param config a config list, as returned by `load_config()`
#' @param resolution grid resolution in arc-minutes, as `marmap` defines it;
#'   smaller is finer and slower. 4 is roughly 7 km at these latitudes.
#' @param keep whether `marmap` should cache the downloaded grid for reuse
#' @return a `terra::SpatRaster` with one layer per covariate in
#'   `bathymetry_covariates()`, in EPSG:4326
#' @export
fetch_bathymetry <- function(config, resolution = 4, keep = TRUE) {
  if (!requireNamespace("marmap", quietly = TRUE)) {
    stop("The 'marmap' package is required for bathymetry covariates. ",
         "Install it with install.packages('marmap').", call. = FALSE)
  }

  bbox <- config$study_area$bbox
  cache_dir <- file.path(config$paths$output_dir, "bathymetry")
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

  bathy <- marmap::getNOAA.bathy(
    lon1 = bbox$xmin, lon2 = bbox$xmax,
    lat1 = bbox$ymin, lat2 = bbox$ymax,
    resolution = resolution, keep = keep, path = cache_dir
  )

  bathymetry_layers(bathy)
}

#' Convert a marmap bathy object into depth, slope, and aspect layers
#'
#' Split from `fetch_bathymetry()` so the conversion can be tested without a
#' network call.
#'
#' @param bathy a `marmap` `bathy` object
#' @return a `terra::SpatRaster` with `DEPTH`, `SLOPE`, and `ASPECT` layers
#' @keywords internal
bathymetry_layers <- function(bathy) {
  # marmap stores elevation with land positive and depth negative. The model
  # wants depth as a positive magnitude, matching the original's log(abs(bat)).
  elevation <- terra::rast(marmap::as.raster(bathy))
  terra::crs(elevation) <- "EPSG:4326"

  depth <- -elevation
  # Land becomes negative depth. Mask it rather than leaving values the model
  # would treat as very shallow water.
  depth[depth <= 0] <- NA
  names(depth) <- "DEPTH"

  terrain <- terra::terrain(depth, v = c("slope", "aspect"), unit = "degrees")
  names(terrain) <- c("SLOPE", "ASPECT")

  c(depth, terrain)
}

#' Attach static bathymetry covariates to a table of points
#'
#' Bathymetry does not vary in time, so the same value is attached to every
#' observation at a location regardless of its date.
#'
#' @param dat a data frame with `lon` and `lat` columns
#' @param bathy a `SpatRaster` from `fetch_bathymetry()`
#' @param vars which layers to attach; `NULL` uses all of them
#' @return `dat` with one column per requested bathymetry covariate
#' @export
attach_bathymetry <- function(dat, bathy, vars = NULL) {
  vars <- vars %||% names(bathy)
  missing <- setdiff(vars, names(bathy))
  if (length(missing) > 0) {
    stop("Bathymetry layers not available: ", paste(missing, collapse = ", "),
         "\nAvailable: ", paste(names(bathy), collapse = ", "), call. = FALSE)
  }

  extracted <- terra::extract(bathy[[vars]], as.matrix(dat[c("lon", "lat")]))
  for (v in vars) dat[[v]] <- extracted[[v]]
  dat
}
