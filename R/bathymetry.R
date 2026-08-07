#' Static seafloor covariates
#'
#' The definitions come from [datamatch::bathymetry_variables()], which owns them
#' so every consumer describes a covariate identically.
#'
#' These are *static* — they do not vary by month or year — so they are fetched
#' once for the study area and attached to every time step, unlike the Copernicus
#' covariates. They replace the SRTM30 depth, slope, and distance-to-shore layers
#' the original model used (`original/load_covars.R` lines 98-104), which came
#' from a server that no longer exists.
#'
#' Fetching and attaching are [datamatch::fetch_bathymetry()] and
#' [datamatch::attach_bathymetry()] directly; this package only supplies the
#' study area and cache location from a config.
#'
#' @return a named list, one entry per covariate, each with `label`, `units`, and
#'   `description`
#' @examples
#' names(bathymetry_covariates())
#' @references
#' NOAA National Centers for Environmental Information (2022). *ETOPO 2022
#' 15 Arc-Second Global Relief Model*. \doi{10.25921/fd45-gt74} — the terrain
#' itself; `datamatch::fetch_bathymetry()` requests its 60 arc-second bedrock
#' grid
#'
#' Pante E, Simon-Bouhet B (2013). marmap: a package for importing, plotting and
#' analyzing bathymetric and topographic data in R. *PLoS ONE* **8**(9), e73051.
#' \doi{10.1371/journal.pone.0073051} — how it is downloaded
#' @export
bathymetry_covariates <- function() {
  datamatch::bathymetry_variables()
}

#' Fetch bathymetry for the configured study area
#'
#' Supplies the study area and cache location from the config, so a run's
#' downloads land with the rest of its outputs rather than wherever R was
#' started.
#'
#' @param config a config list, as returned by `load_config()`
#' @param resolution grid resolution in arc-minutes; smaller is finer and slower.
#'   4 is roughly 7 km at these latitudes.
#' @return a `terra::SpatRaster` with one layer per covariate, in EPSG:4326
#' @keywords internal
study_area_bathymetry <- function(config, resolution = 4) {
  bbox <- config$study_area$bbox
  datamatch::fetch_bathymetry(
    bounding_box = list(xmin = bbox$xmin, xmax = bbox$xmax,
                        ymin = bbox$ymin, ymax = bbox$ymax),
    resolution = resolution,
    path = file.path(config$paths$output_dir, "bathymetry")
  )
}
