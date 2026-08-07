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
#' @references
#' Three Copernicus Marine products supply these, and a run should cite whichever
#' of them it fetched from. E.U. Copernicus Marine Service Information:
#'
#' *Global Ocean Physics Reanalysis* (GLORYS12V1) — `SST`, `SSS`, `BOTT`, `UO`,
#' `VO`, `SSH`, `MLD`, `SIC`. \doi{10.48670/moi-00021}
#'
#' *Global Ocean Colour* (Copernicus-GlobColour) — satellite `CHL`, `PP`,
#' `DIATO`, `DINO`. \doi{10.48670/moi-00281}
#'
#' *Global Ocean Biogeochemistry Hindcast* — `NO3`, `PO4`, `O2`, `PH`,
#' `CHL_MODEL`, `NPP_MODEL`. \doi{10.48670/moi-00019}
#'
#' Downloads go through the Copernicus Marine Toolbox
#' (<https://toolbox-docs.marine.copernicus.eu/>), which has no DOI of its own —
#' credit it by name, and cite the product.
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

#' Climate indices selectable as covariates
#'
#' Basin-scale modes of variability — the NAO, the AMO and the rest — from
#' [datamatch::climate_indices()], which owns them.
#'
#' Unlike everything else in the covariate catalog these have no spatial
#' structure. One value per month applies to the whole study area, so an index
#' cannot say where a patch is, only which years and seasons were unusual. That
#' makes them useful for the interannual part of the signal and useless for the
#' map: a projection differs between two months partly because the index differs,
#' but the index shifts every cell by the same amount.
#'
#' @return a named list, one entry per index, each with `label`, `source`, and
#'   `description`
#' @examples
#' names(climate_index_covariates())
#' @references
#' Each index is somebody's published product, and the `source` field names
#' whose. `datamatch::index_dictionary()` carries the citation for each one at
#' runtime; two of them (`LCR`, `AMOC`) are the output of specific papers and
#' should be cited when used. See datamatch's README for the list.
#' @export
climate_index_covariates <- function() {
  datamatch::climate_indices()
}

#' Attach the configured climate indices to a table
#'
#' Joined on year and month, since that is the resolution the indices are
#' published at and the resolution this pipeline runs at.
#'
#' @param dat a data frame with year and month columns
#' @param config a config list, as returned by `load_config()`
#' @param year_col,month_col the columns to join on
#' @return `dat` with one column per configured index
#' @keywords internal
attach_climate_indices <- function(dat, config, year_col = "year",
                                   month_col = "month") {
  indices <- config$covariates$climate
  if (length(indices) == 0) return(dat)

  datamatch::attach_climate_index(dat, indices, year_col = year_col,
                                  month_col = month_col)
}
