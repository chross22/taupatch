#' Catalog of selectable environmental covariates
#'
#' Maps short, familiar names (`SST`, `CHL`, ...) onto the Copernicus Marine
#' product, dataset, and variable that supply them, so a run names covariates the
#' way people talk about them rather than by Copernicus variable code.
#'
#' All entries are monthly means, matching this pipeline's monthly timescale.
#' Physical variables come from the global physics reanalysis and biogeochemical
#' ones from the global biogeochemistry reanalysis; covariates sharing a dataset
#' are fetched together in one request.
#'
#' Copernicus revises dataset identifiers periodically. If a fetch fails with an
#' unknown-dataset error, check the current identifier on the Copernicus Marine
#' Data Store and override it in the config's `covariates.copernicus` block.
#'
#' @return a named list, one entry per covariate, each with `label`, `units`,
#'   `variable`, `product_id`, `dataset_id`, `depth`, and `description`
#' @examples
#' names(copernicus_covariates())
#' copernicus_covariates()$SST$units
#' @export
copernicus_covariates <- function() {
  phy_product <- "GLOBAL_MULTIYEAR_PHY_001_030"
  phy_dataset <- "cmems_mod_glo_phy_my_0.083deg_P1M-m"
  bgc_product <- "GLOBAL_MULTIYEAR_BGC_001_029"
  bgc_dataset <- "cmems_mod_glo_bgc_my_0.25deg_P1M-m"

  list(
    SST = list(
      label = "Sea surface temperature", units = "degrees C", variable = "thetao",
      product_id = phy_product, dataset_id = phy_dataset, depth = c(0, 1),
      description = paste("Sea water potential temperature at the surface.",
                          "The strongest single driver in the original model.")
    ),
    SSS = list(
      label = "Sea surface salinity", units = "PSU", variable = "so",
      product_id = phy_product, dataset_id = phy_dataset, depth = c(0, 1),
      description = "Sea water salinity at the surface."
    ),
    BOTT = list(
      label = "Bottom temperature", units = "degrees C", variable = "bottomT",
      product_id = phy_product, dataset_id = phy_dataset, depth = c(0, 1),
      description = paste("Sea water potential temperature at the sea floor.",
                          "Relevant to overwintering copepod stages.")
    ),
    UO = list(
      label = "Eastward current velocity", units = "m/s", variable = "uo",
      product_id = phy_product, dataset_id = phy_dataset, depth = c(0, 1),
      description = "Eastward component of sea water velocity."
    ),
    VO = list(
      label = "Northward current velocity", units = "m/s", variable = "vo",
      product_id = phy_product, dataset_id = phy_dataset, depth = c(0, 1),
      description = "Northward component of sea water velocity."
    ),
    SSH = list(
      label = "Sea surface height", units = "m", variable = "zos",
      product_id = phy_product, dataset_id = phy_dataset, depth = c(0, 1),
      description = paste("Sea surface height above geoid. A proxy for",
                          "mesoscale circulation features.")
    ),
    MLD = list(
      label = "Mixed layer depth", units = "m", variable = "mlotst",
      product_id = phy_product, dataset_id = phy_dataset, depth = c(0, 1),
      description = paste("Ocean mixed layer thickness, defined by a sigma-theta",
                          "criterion. Controls how deeply plankton are mixed.")
    ),
    CHL = list(
      label = "Chlorophyll-a concentration", units = "mg/m3", variable = "chl",
      product_id = bgc_product, dataset_id = bgc_dataset, depth = c(0, 1),
      description = paste("Mass concentration of chlorophyll-a. A food-availability",
                          "proxy; usually worth log-transforming.")
    ),
    NO3 = list(
      label = "Nitrate concentration", units = "mmol/m3", variable = "no3",
      product_id = bgc_product, dataset_id = bgc_dataset, depth = c(0, 1),
      description = "Mole concentration of nitrate, a limiting nutrient."
    ),
    O2 = list(
      label = "Dissolved oxygen", units = "mmol/m3", variable = "o2",
      product_id = bgc_product, dataset_id = bgc_dataset, depth = c(0, 1),
      description = "Mole concentration of dissolved molecular oxygen."
    )
  )
}

#' Covariate reference table
#'
#' The catalog as a data frame, for display in documentation or the app's
#' covariate reference tab.
#'
#' @param include_derived also describe covariates computed by the pipeline
#'   rather than fetched
#' @return a data frame with `name`, `label`, `units`, `variable`, `dataset`,
#'   and `description` columns
#' @examples
#' covariate_info()[, c("name", "label", "units")]
#' @export
covariate_info <- function(include_derived = TRUE) {
  catalog <- copernicus_covariates()
  info <- do.call(rbind, lapply(names(catalog), function(name) {
    entry <- catalog[[name]]
    data.frame(
      name = name, label = entry$label, units = entry$units,
      variable = entry$variable, dataset = entry$dataset_id,
      description = entry$description, stringsAsFactors = FALSE
    )
  }))

  bathymetry <- bathymetry_covariates()
  info <- rbind(info, do.call(rbind, lapply(names(bathymetry), function(name) {
    entry <- bathymetry[[name]]
    data.frame(
      name = name, label = entry$label, units = entry$units,
      variable = "(static)", dataset = "NOAA ETOPO, via marmap::getNOAA.bathy()",
      description = entry$description, stringsAsFactors = FALSE
    )
  })))

  if (include_derived) {
    info <- rbind(info, data.frame(
      name = "jday", label = "Day of year", units = "day (1-366)",
      variable = "(derived)", dataset = "(computed from the observation date)",
      description = paste("Seasonality term. This is what lets a single pooled",
                          "model produce month-specific projections rather than",
                          "needing twelve separate models."),
      stringsAsFactors = FALSE
    ))
  }
  info
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
