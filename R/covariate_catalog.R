#' Catalog of selectable environmental covariates
#'
#' The variable definitions come from [datamatch::copernicus_variables()], which
#' owns them so every consumer describes a covariate identically. This adds the
#' one field the pipeline needs on top: the depth range to request.
#'
#' All entries are monthly means, matching this pipeline's monthly timescale.
#' Covariates sharing a dataset are fetched together in one request.
#'
#' Copernicus revises dataset identifiers periodically. If a fetch fails with an
#' unknown-dataset error, check the current identifier on the Copernicus Marine
#' Data Store (`datamatch::product_url()` links to the product page) and override
#' it in the config's `covariates.copernicus` block.
#'
#' @return a named list, one entry per covariate, each with `label`, `units`,
#'   `variable`, `product_id`, `dataset_id`, `depth`, and `description`
#' @examples
#' names(copernicus_covariates())
#' copernicus_covariates()$SST$units
#' @seealso [datamatch::variable_dictionary()] for the full variable listing
#' @export
copernicus_covariates <- function() {
  lapply(datamatch::copernicus_variables(), function(entry) {
    # Surface fields throughout; the pipeline models surface habitat, and
    # accessEnvDat() can only return one depth level per request anyway.
    entry$depth <- c(0, 1)
    entry
  })
}

#' Covariate reference table
#'
#' The catalog as a data frame, for display in documentation or the app's
#' covariate reference tab.
#'
#' @param include_derived also describe covariates computed by the pipeline
#'   rather than fetched
#' @return a data frame with `name`, `label`, `units`, `variable`, `dataset`,
#'   `spatial`, `temporal`, and `description` columns
#' @examples
#' covariate_info()[, c("name", "label", "units")]
#' covariate_info()[, c("name", "spatial", "temporal")]
#' @export
covariate_info <- function(include_derived = TRUE) {
  catalog <- copernicus_covariates()
  info <- do.call(rbind, lapply(names(catalog), function(name) {
    entry <- catalog[[name]]
    resolution <- dataset_resolution(entry$dataset_id)
    data.frame(
      name = name, label = entry$label, units = entry$units,
      variable = entry$variable, dataset = entry$dataset_id,
      spatial = resolution$spatial, temporal = resolution$temporal,
      description = entry$description, stringsAsFactors = FALSE
    )
  }))

  bathymetry <- bathymetry_covariates()
  info <- rbind(info, do.call(rbind, lapply(names(bathymetry), function(name) {
    entry <- bathymetry[[name]]
    data.frame(
      name = name, label = entry$label, units = entry$units,
      variable = "(static)", dataset = "NOAA ETOPO, via marmap::getNOAA.bathy()",
      # The default resolution of study_area_bathymetry(); a run can ask for a
      # finer grid, which is why this says "default".
      spatial = "4 arc-min (~7 km), default",
      temporal = "static",
      description = entry$description, stringsAsFactors = FALSE
    )
  })))

  if (include_derived) {
    info <- rbind(info, data.frame(
      name = "jday", label = "Day of year", units = "day (1-366)",
      variable = "(derived)", dataset = "(computed from the observation date)",
      spatial = "n/a", temporal = "per observation",
      description = paste("Seasonality term. This is what lets a single pooled",
                          "model produce month-specific projections rather than",
                          "needing twelve separate models."),
      stringsAsFactors = FALSE
    ))

    # The derivoce entries are step *types* rather than single covariates: one
    # step produces a column per variable it is given, named for the variable it
    # came from. What a configured run will actually produce is
    # `derivoce_names()`.
    derived <- derivoce_covariates()
    info <- rbind(info, do.call(rbind, lapply(names(derived), function(name) {
      entry <- derived[[name]]
      data.frame(
        name = name, label = entry$label, units = entry$units,
        variable = "(derived)",
        dataset = "(computed from the covariate grid by derivoce)",
        # A derived covariate inherits the grid it was computed on, so its
        # resolution is whichever of its inputs the grid was joined onto.
        spatial = "as its inputs", temporal = "as its inputs",
        description = entry$description, stringsAsFactors = FALSE
      )
    })))
  }
  info
}

#' Spatial and temporal resolution encoded in a Copernicus dataset id
#'
#' Copernicus dataset identifiers carry both — `cmems_mod_glo_phy_my_0.083deg_P1M-m`
#' is a 0.083 degree grid of monthly means — so the resolutions are read off the
#' id rather than maintained as a second list that could disagree with it.
#'
#' Grids are stated two ways in these identifiers. Model products give degrees
#' (`0.083deg`, `0.25deg`); satellite products give kilometres (`4km`). Both are
#' parsed, because which is finer is not obvious across the two conventions and
#' is exactly what a run needs to know: the 4 km ocean-colour chlorophyll is
#' *finer* than the 0.083 degree physics it would be joined to, while the 0.25
#' degree model chlorophyll is much coarser than both.
#'
#' The kilometre figures for degree grids are one degree of latitude, about
#' 111 km. A degree of longitude is shorter — some 83 km at 42 degrees north — so
#' these are an upper bound on cell width, which is the useful direction to err
#' in.
#'
#' @param dataset_id a Copernicus dataset identifier
#' @return `list(spatial=, temporal=)`, each a display string, or `"unknown"`
#'   where the id does not encode it
#' @keywords internal
dataset_resolution <- function(dataset_id) {
  degrees <- regmatches(dataset_id, regexpr("[0-9]+\\.?[0-9]*(?=deg)", dataset_id,
                                             perl = TRUE))
  kilometres <- regmatches(dataset_id, regexpr("[0-9]+\\.?[0-9]*(?=km)", dataset_id,
                                                perl = TRUE))
  spatial <- if (length(degrees) == 1) {
    paste0(degrees, "\u00b0 (~", round(as.numeric(degrees) * 111), " km)")
  } else if (length(kilometres) == 1) {
    paste0(kilometres, " km (~", signif(as.numeric(kilometres) / 111, 2), "\u00b0)")
  } else {
    "unknown"
  }

  # ISO 8601 durations: P1D daily, P1M monthly, P1Y annual.
  period <- regmatches(dataset_id, regexpr("P([0-9]+)([DMY])", dataset_id))
  temporal <- if (length(period) == 1) {
    count <- as.integer(sub("P([0-9]+)([DMY])", "\\1", period))
    unit <- sub("P([0-9]+)([DMY])", "\\2", period)
    label <- c(D = "daily", M = "monthly", Y = "annual")[[unit]]
    if (count == 1) label else paste0(count, "-", sub("ly$", "", label), " means")
  } else {
    "unknown"
  }

  list(spatial = spatial, temporal = temporal)
}

#' Resolve selected covariate names to Copernicus fetch specifications
#'
#' Covariates sharing a product and dataset are grouped into one specification,
#' so selecting SST, SSS, and MLD costs one request rather than three.
#'
#' @param selected covariate names, as in `copernicus_covariates()`
#' @return a list of specs with `product_id`, `dataset_id`, `vars`, `depth`, and
#'   `names` (the covariate names each variable maps back to)
#' @keywords internal
resolve_covariate_specs <- function(selected) {
  catalog <- copernicus_covariates()

  unknown <- setdiff(selected, names(catalog))
  if (length(unknown) > 0) {
    stop("Unknown covariate(s): ", paste(unknown, collapse = ", "),
         "\nAvailable: ", paste(names(catalog), collapse = ", "), call. = FALSE)
  }

  keys <- vapply(selected, function(name) {
    entry <- catalog[[name]]
    paste(entry$product_id, entry$dataset_id, sep = "|")
  }, character(1))

  lapply(unique(keys), function(key) {
    group <- selected[keys == key]
    entries <- catalog[group]
    list(
      product_id = entries[[1]]$product_id,
      dataset_id = entries[[1]]$dataset_id,
      vars = unname(vapply(entries, function(e) e$variable, character(1))),
      depth = entries[[1]]$depth,
      names = group
    )
  })
}
