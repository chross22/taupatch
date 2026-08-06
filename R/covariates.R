#' Fetch environmental covariates
#'
#' Dispatches on `covariates.source` in the config. The `"copernicus"` source
#' fetches from Copernicus Marine via `datamatch::accessEnvDat()`; `"local_netcdf"`
#' reads a directory of NetCDF files already on disk; `"mock"` generates synthetic
#' covariates so the pipeline can run without network access.
#'
#' All three return the same shape, so everything downstream is source-agnostic.
#'
#' @param config a config list, as returned by `load_config()`
#' @param years years to fetch; defaults to the config's year range
#' @param months months to fetch; defaults to the config's month range
#' @return an `sf` POINT object with one row per (grid point, time step), a column
#'   per covariate variable, and `YEAR`/`MONTH`/`DAY` columns
#' @export
fetch_covariates <- function(config, years = NULL, months = NULL) {
  period <- covariate_period(config)
  years <- years %||% period$years
  months <- months %||% period$months

  switch(
    config$covariates$source,
    copernicus = fetch_covariates_copernicus(config, years, months),
    local_netcdf = fetch_covariates_netcdf(config, years, months),
    mock = generate_mock_covariates(config, years, months)
  )
}

#' Fetch covariates from Copernicus Marine
#'
#' One `datamatch::accessEnvDat()` call per dataset entry in
#' `covariates.copernicus`, joined on grid point and date. This replaces the ~200
#' lines of hardcoded per-variable raster paths in `original/load_covars.R`.
#'
#' @param config a config list, as returned by `load_config()`
#' @param years years to fetch
#' @param months months to fetch
#' @return an `sf` POINT object; see `fetch_covariates()`
#' @keywords internal
fetch_covariates_copernicus <- function(config, years, months) {
  if (!requireNamespace("datamatch", quietly = TRUE)) {
    stop("The 'datamatch' package is required for covariates.source: copernicus. ",
         "Install it with remotes::install_github('chross22/datamatch').", call. = FALSE)
  }

  bbox <- config$study_area$bbox
  bounding_box <- list(xmin = bbox$xmin, xmax = bbox$xmax,
                       ymin = bbox$ymin, ymax = bbox$ymax)

  specs <- covariate_specs(config)

  per_dataset <- lapply(specs, function(spec) {
    args <- list(
      product_id = spec$product_id,
      dataset_id = spec$dataset_id,
      vars = spec$vars,
      years = years,
      months = months,
      bounding_box = bounding_box,
      depth = spec$depth %||% c(0, 1)
    )
    # Parallel fetching was added to datamatch after some installed versions;
    # only pass it when asked for, so an older datamatch still works.
    if (!is.null(spec$n_workers %||% config$covariates$n_workers)) {
      args$n_workers <- spec$n_workers %||% config$covariates$n_workers
    }
    fetched <- do.call(datamatch::accessEnvDat, args)

    # Present the columns under the covariate names the config asked for rather
    # than Copernicus variable codes, so the model's predictors read as SST/CHL.
    if (!is.null(spec$names)) {
      names(fetched)[match(spec$vars, names(fetched))] <- spec$names
    }
    fetched
  })

  # Which grid the result lands on is a real choice, so it is a config field
  # rather than an accident of the order the specs happened to come in.
  spacing <- vapply(per_dataset, grid_spacing, numeric(1))
  grid <- config$covariates$grid %||% "finest"
  ordering <- order(spacing, decreasing = (grid == "coarsest"))
  per_dataset <- per_dataset[ordering]

  joined <- Reduce(join_covariate_sources, per_dataset)

  # Record which covariates were rendered onto a grid finer than their own, so
  # a caller can tell blocky values from real detail. A gradient computed from
  # one of these measures the source grid, not the ocean.
  target <- spacing[ordering][1]
  upsampled <- unlist(lapply(seq_along(per_dataset), function(i) {
    if (spacing[ordering][i] <= target) return(NULL)
    datamatch::covariate_columns(per_dataset[[i]])
  }))
  attr(joined, "upsampled") <- upsampled

  if (length(upsampled) > 0) {
    message("  ", paste(upsampled, collapse = ", "),
            " upsampled from a coarser grid; values repeat within each source cell")
  }
  joined
}

#' @section Combining products of different resolution:
#' Copernicus products do not share a grid — physics is 0.083 degrees,
#' biogeochemistry 0.25 — so selecting `SST` and `CHL` together means two grids
#' that have to be reconciled onto one.
#'
#' `covariates.grid` decides which:
#'
#' \itemize{
#'   \item `"finest"` (the default) keeps the finest grid and repeats each
#'     coarse cell's value across the fine cells inside it. Fine-scale structure
#'     in the fine variables survives, which matters because fronts and gradients
#'     are computed from them and a coarse grid would smooth those away.
#'   \item `"coarsest"` joins onto the coarsest grid instead, so no value is ever
#'     replicated.
#' }
#'
#' The cost of `"finest"` is worth stating plainly: a coarse variable rendered on
#' a fine grid is blocky, not detailed. Its values are constant within each
#' original cell and step at the boundaries, so a **spatial gradient computed
#' from an upsampled variable is an artifact** — zero inside each block, spiking
#' at block edges that are an artifact of the source grid rather than a feature
#' of the ocean. Compute gradients from variables at their native resolution.
#'
#' Which covariates were upsampled is recorded on the result as an `upsampled`
#' attribute.
#'
#' @rdname fetch_covariates
#' @name covariate-resolution
NULL

#' Grid spacing of a covariate source, in degrees
#'
#' The measurement is [datamatch::grid_resolution()], which owns it; this reduces
#' its per-axis answer to the single number the join needs, the coarser of the
#' two. A grid finer in one direction than the other is still limited by its
#' coarse direction, so that is what decides which source is the finer of two.
#'
#' @param env_dat an `sf` POINT object from `datamatch::accessEnvDat()`
#' @return the coarser of the longitude and latitude spacings
#' @keywords internal
grid_spacing <- function(env_dat) {
  max(datamatch::grid_resolution(env_dat), na.rm = TRUE)
}

#' Copernicus fetch specifications for a config
#'
#' Prefers the covariate names in `covariates.selected`, resolved through
#' [copernicus_covariates()]. A raw `covariates.copernicus` block remains
#' available for datasets the catalog does not cover.
#'
#' @param config a config list, as returned by `load_config()`
#' @return a list of fetch specifications
#' @keywords internal
covariate_specs <- function(config) {
  if (length(config$covariates$selected) > 0) {
    return(resolve_covariate_specs(config$covariates$selected))
  }
  config$covariates$copernicus
}

#' Join covariate sets from two products onto the same points
#'
#' @param x an `sf` POINT covariate object
#' @param y another `sf` POINT covariate object
#' @return `x` with `y`'s variable columns joined on nearest point and date
#' @keywords internal
join_covariate_sources <- function(x, y) {
  y_vars <- datamatch::covariate_columns(y)

  # Joined one time step at a time. A single spatial join across the whole
  # stack matches on geometry alone, and because every time step repeats the
  # same coordinates, st_nearest_feature would resolve the tie to one arbitrary
  # step - attaching the first month's chlorophyll to every month, silently and
  # plausibly. This matters whenever two products have different grids, which
  # is the normal case: Copernicus physics is 0.083 degrees and biogeochemistry
  # 0.25.
  steps <- unique(sf::st_drop_geometry(x)[c("YEAR", "MONTH", "DAY")])
  y_time <- sf::st_drop_geometry(y)[c("YEAR", "MONTH", "DAY")]

  joined <- lapply(seq_len(nrow(steps)), function(i) {
    step <- steps[i, ]
    x_rows <- x$YEAR == step$YEAR & x$MONTH == step$MONTH & x$DAY == step$DAY
    y_rows <- y_time$YEAR == step$YEAR & y_time$MONTH == step$MONTH &
      y_time$DAY == step$DAY

    if (!any(y_rows)) {
      # The second product has no data for this step. Fill rather than drop, so
      # the row count does not silently depend on which products were selected.
      missing <- x[x_rows, ]
      for (v in y_vars) missing[[v]] <- NA_real_
      return(missing)
    }

    sf::st_join(x[x_rows, ], y[y_rows, y_vars],
                join = sf::st_nearest_feature, suffix = c("", ".y"))
  })

  result <- do.call(rbind, joined)
  result[!grepl("\\.y$", names(result))]
}

#' Read covariates from a directory of NetCDF files
#'
#' For when the covariate files are already on disk rather than being fetched.
#'
#' @param config a config list, as returned by `load_config()`
#' @param years years to keep
#' @param months months to keep
#' @return an `sf` POINT object; see `fetch_covariates()`
#' @keywords internal
fetch_covariates_netcdf <- function(config, years, months) {
  files <- list.files(config$paths$covariate_dir, pattern = "\\.nc$", full.names = TRUE)
  if (length(files) == 0) {
    stop("No .nc files found in paths.covariate_dir: ", config$paths$covariate_dir,
         call. = FALSE)
  }

  frames <- lapply(files, function(path) {
    r <- terra::rast(path)
    dates <- as.Date(terra::time(r))
    df <- as.data.frame(r, xy = TRUE)
    df$YEAR <- as.integer(format(dates[1], "%Y"))
    df$MONTH <- as.integer(format(dates[1], "%m"))
    df$DAY <- as.integer(format(dates[1], "%d"))
    df
  })

  covars <- do.call(rbind, frames)
  covars <- covars[covars$YEAR %in% years & covars$MONTH %in% months, ]
  sf::st_as_sf(covars, coords = c("x", "y"), crs = sf::st_crs(4326))
}

#' Attach covariates to zooplankton stations
#'
#' Matches each station to the nearest covariate grid point within the station's
#' own time period, via `datamatch::matchData()`. This replaces
#' `original/format_model_data.R`, which rounded both sets of coordinates to one
#' decimal place and then joined on exact equality — silently dropping any station
#' whose rounded position had no covariate match.
#'
#' `matchData()` matches at the covariate data's own temporal resolution, which
#' for this pipeline is monthly: the original used monthly covariate composites,
#' and the Copernicus products configured here are monthly means (`...P1M-m`)
#' carrying one time step per month, while stations fall on arbitrary days.
#'
#' @param dat station data from `load_zoop_data()`
#' @param env_dat covariate data from `fetch_covariates()`
#' @param config a config list, as returned by `load_config()`
#' @return `dat` with one column per covariate variable, with unmatched rows dropped
#' @export
attach_covariates <- function(dat, env_dat, config) {
  if (!requireNamespace("datamatch", quietly = TRUE)) {
    stop("The 'datamatch' package is required. ",
         "Install it with remotes::install_github('chross22/datamatch').", call. = FALSE)
  }

  vars <- datamatch::covariate_columns(env_dat)
  stations <- sf::st_as_sf(dat, coords = c("lon", "lat"), crs = sf::st_crs(4326),
                           remove = FALSE)

  matched <- datamatch::matchData(speciesDat = stations, envDat = env_dat)

  out <- sf::st_drop_geometry(matched) |> tibble::as_tibble()
  names(out)[names(out) == "YEAR"] <- "year"
  names(out)[names(out) == "MONTH"] <- "month"
  names(out)[names(out) == "DAY"] <- "day"

  drop_missing(out, vars)
}

#' Drop rows with missing values in the given columns
#'
#' @param dat a data frame
#' @param cols column names to check
#' @return `dat` with incomplete rows removed
#' @keywords internal
drop_missing <- function(dat, cols) {
  cols <- intersect(cols, names(dat))
  if (length(cols) == 0) return(dat)
  dat[stats::complete.cases(dat[cols]), ]
}

#' Average each covariate over the study area, per month and year
#'
#' Collapses the covariate grid to one value per (year, month, covariate) — the
#' spatial mean across the study area. Summarizing during a run rather than
#' returning the full grid keeps the result small: a multi-decade Copernicus fetch
#' is millions of grid points, while its summary is a few hundred rows.
#'
#' @param env_dat covariate data from `fetch_covariates()`
#' @param vars covariate names to summarize; `NULL` uses all of them
#' @return a data frame with `year`, `month`, `covariate`, and `mean` columns
#' @export
covariate_monthly_means <- function(env_dat, vars = NULL) {
  vars <- vars %||% datamatch::covariate_columns(env_dat)
  flat <- sf::st_drop_geometry(env_dat)

  means <- lapply(vars, function(v) {
    aggregated <- stats::aggregate(flat[[v]], by = list(year = flat$YEAR, month = flat$MONTH),
                                   FUN = mean, na.rm = TRUE)
    names(aggregated)[3] <- "mean"
    aggregated$covariate <- v
    aggregated
  })

  out <- do.call(rbind, means)
  out <- out[order(out$covariate, out$year, out$month), c("year", "month", "covariate", "mean")]
  rownames(out) <- NULL
  out
}

#' Build the covariate grid for one month
#'
#' The prediction surface a fitted model is projected onto: every covariate grid
#' point for one (year, month), with derived covariates added so the grid carries
#' the same predictors the model was trained on.
#'
#' @param env_dat covariate data from `fetch_covariates()`
#' @param year year to extract
#' @param month month to extract
#' @param config a config list, as returned by `load_config()`
#' @return a tibble with `lon`, `lat`, and one column per predictor, or `NULL` if
#'   the covariate data has no points for that year and month
#' @export
covariate_grid <- function(env_dat, year, month, config) {
  slice <- env_dat[env_dat$YEAR == year & env_dat$MONTH == month, ]
  if (nrow(slice) == 0) return(NULL)

  coords <- sf::st_coordinates(slice)
  grid <- tibble::as_tibble(sf::st_drop_geometry(slice))
  grid$lon <- coords[, 1]
  grid$lat <- coords[, 2]
  grid$year <- year
  grid$month <- month
  grid$day <- 15L

  add_derived_covariates(grid, config)
}

#' Add derived covariates
#'
#' Covariates computed from the data rather than fetched. `jday` is day-of-year,
#' which is how the pooled model represents seasonality — it is what lets one
#' model, rather than twelve, produce month-specific projections.
#'
#' @param dat a data frame with `year`, `month`, and `day` columns
#' @param config a config list, as returned by `load_config()`
#' @return `dat` with the configured derived covariates added
#' @keywords internal
add_derived_covariates <- function(dat, config) {
  if ("jday" %in% config$covariates$derived) {
    dat$jday <- as.integer(format(
      as.Date(paste(dat$year, dat$month, dat$day, sep = "-")), "%j"
    ))
  }
  dat
}

#' Predictor names for a model
#'
#' Every covariate variable plus configured derived covariates, excluding the
#' identity, coordinate, and response columns.
#'
#' @param dat modeling data, as returned by `attach_covariates()`
#' @param config a config list, as returned by `load_config()`
#' @return character vector of predictor column names
#' @keywords internal
predictor_names <- function(dat, config) {
  non_predictors <- c("lon", "lat", "LON", "LAT", "year", "month", "day",
                      "dataset", "station", "abundance", "patch")
  candidates <- setdiff(names(dat), non_predictors)
  candidates[vapply(dat[candidates], is.numeric, logical(1))]
}
