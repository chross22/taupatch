#' Derived covariates computed from the covariate grid
#'
#' Covariates the pipeline computes rather than downloads: spatial and temporal
#' gradients, distances to fronts and contours, lags, integrals, and flow
#' diagnostics. The computation is
#' [derivoce](https://github.com/chross22/derivoce) throughout, which owns the
#' definitions so every consumer computes them identically; this package supplies
#' the config block naming which ones a run wants and threads the results through
#' the rest of the pipeline.
#'
#' Every entry describes one derivoce function that a `covariates.derivoce` step
#' can name. `inputs` gives the step fields that name covariate columns, with
#' their defaults: `""` marks a field the config must supply, `NA` an optional one
#' with no default. `neighbourhood` marks the steps that read a point's
#' surroundings rather than only its own value, which is what makes upsampling
#' matter (see [add_derivoce_covariates()]).
#'
#' @return a named list, one entry per supported step type, each with `label`,
#'   `units`, `description`, `inputs`, `neighbourhood`, `required` (extra fields
#'   with no default), and `outputs` (a function giving the column names a step of
#'   that type produces)
#' @examples
#' names(derivoce_covariates())
#' derivoce_covariates()$horizontal_gradient$units
#'
#' # The column names a step will produce, before running it.
#' derivoce_covariates()$lag_covariate$outputs(list(vars = "CHL", n = 2))
#' @seealso [add_derivoce_covariates()], which runs the configured steps
#' @export
derivoce_covariates <- function() {
  list(
    horizontal_gradient = list(
      label = "Horizontal gradient",
      units = "source units per km",
      description = paste(
        "Magnitude of a covariate's change with distance. Large where fronts are,",
        "and fronts are the convergence zones where plankton aggregate. In units",
        "per kilometre rather than per degree, so values are comparable across the",
        "study area."
      ),
      inputs = c(vars = ""),
      neighbourhood = TRUE,
      outputs = function(spec) {
        base <- paste0(spec$vars, spec$suffix %||% "_grad")
        if (isTRUE(spec$components)) {
          c(rbind(base, paste0(base, "_x"), paste0(base, "_y")))
        } else {
          base
        }
      }
    ),
    vertical_gradient = list(
      label = "Vertical gradient",
      units = "source units, or per m when `depth` is given",
      description = paste(
        "Surface-minus-bottom difference: a stratification index, large where a",
        "warm surface layer sits over cold deep water and near zero where the",
        "column is well mixed. Both inputs come from the same Copernicus dataset,",
        "so this needs no extra download."
      ),
      inputs = c(surface = "SST", bottom = "BOTT", depth = NA),
      neighbourhood = FALSE,
      outputs = function(spec) {
        spec$name %||% paste0(spec$surface %||% "SST", "_",
                              spec$bottom %||% "BOTT", "_vgrad")
      }
    ),
    temporal_gradient = list(
      label = "Temporal gradient",
      units = "source units per step, day, or month",
      description = paste(
        "Rate of change between consecutive time steps at each location: how fast",
        "conditions are shifting, as distinct from what they currently are."
      ),
      inputs = c(vars = ""),
      neighbourhood = FALSE,
      outputs = function(spec) paste0(spec$vars, spec$suffix %||% "_tgrad")
    ),
    lag_covariate = list(
      label = "Lagged covariate",
      units = "source units",
      description = paste(
        "The value n steps back. Populations respond with a delay: a bloom feeds",
        "the animals sampled a month later, not those sampled during it."
      ),
      inputs = c(vars = ""),
      neighbourhood = FALSE,
      outputs = function(spec) {
        paste0(spec$vars, spec$suffix %||% paste0("_lag", spec$n %||% 1))
      }
    ),
    integrate_covariate = list(
      label = "Integrated covariate",
      units = "source units, accumulated over the window",
      description = paste(
        "Accumulation over preceding steps. A survey samples the food built up",
        "since the season began, not the food present that instant. The default",
        "window resets each January."
      ),
      inputs = c(vars = ""),
      neighbourhood = FALSE,
      outputs = function(spec) paste0(spec$vars, spec$suffix %||% "_int")
    ),
    current_speed = list(
      label = "Current speed",
      units = "m/s",
      description = paste(
        "Speed from the two current components. Pipe it through a",
        "horizontal_gradient step for the original pipeline's `uv_grad`."
      ),
      inputs = c(u = "UO", v = "VO"),
      neighbourhood = FALSE,
      outputs = function(spec) spec$name %||% "speed"
    ),
    eke = list(
      label = "Eddy kinetic energy",
      units = "m2/s2",
      description = paste(
        "Kinetic energy carried by the flow's departure from its mean, marking",
        "meanders, rings, and eddies rather than strong steady currents.",
        "`reference` decides what the anomaly is measured against, which decides",
        "what counts as an eddy rather than as mean flow."
      ),
      inputs = c(u = "UO", v = "VO"),
      neighbourhood = FALSE,
      outputs = function(spec) spec$name %||% "EKE"
    ),
    ftle = list(
      label = "Finite-time Lyapunov exponent",
      units = "1/day",
      description = paste(
        "Stretching rate of the flow over a fixed window. Backward (the default)",
        "finds attracting structures, where water converges and material",
        "accumulates; forward finds the repelling ones, the transport barriers."
      ),
      inputs = c(u = "UO", v = "VO"),
      neighbourhood = TRUE,
      outputs = function(spec) {
        spec$name %||% paste0(spec$direction %||% "backward", "_ftle")
      }
    ),
    fsle = list(
      label = "Finite-size Lyapunov exponent",
      units = "1/day",
      description = paste(
        "Like the FTLE, but timed to a fixed separation rather than integrated for",
        "a fixed window, so structures of a chosen size are resolved consistently."
      ),
      inputs = c(u = "UO", v = "VO"),
      neighbourhood = TRUE,
      outputs = function(spec) {
        spec$name %||% paste0(spec$direction %||% "backward", "_fsle")
      }
    ),
    distance_to_front = list(
      label = "Distance to front",
      units = "km",
      description = paste(
        "How far each point is from the nearest front. Usually a better predictor",
        "than the local gradient: a station in a smooth patch has zero gradient",
        "whether the nearest front is 2 km away or 200, and those are very",
        "different places to be."
      ),
      inputs = c(var = ""),
      neighbourhood = TRUE,
      outputs = function(spec) spec$name %||% paste0(spec$var, "_front_dist")
    ),
    distance_to_contour = list(
      label = "Distance to a contour",
      units = "km",
      description = paste(
        "Distance to where a covariate crosses a value. Position relative to a",
        "contour is often what matters rather than the value itself."
      ),
      inputs = c(var = ""),
      required = "levels",
      neighbourhood = TRUE,
      outputs = function(spec) {
        paste0(spec$prefix %||% spec$var, "_dist_", spec$levels)
      }
    ),
    distance_to_isobath = list(
      label = "Distance to isobath",
      units = "km",
      description = paste(
        "Distance to depth contours. Plankton track the shelf break, and \"20 km",
        "inshore of the 100 m isobath\" locates that better than \"depth = 85 m\".",
        "Reads a depth column, so the run must also select a bathymetry covariate."
      ),
      inputs = c(depth = "DEPTH"),
      neighbourhood = TRUE,
      outputs = function(spec) {
        paste0("isobath_dist_", spec$levels %||% c(50, 100, 200))
      }
    ),
    distance_to_shore = list(
      label = "Distance to shore",
      units = "km",
      description = paste(
        "Kilometres to the nearest coast, from Natural Earth. This is the original",
        "pipeline's `dist`. A broad proxy for several things at once - depth,",
        "terrestrial input, tidal mixing, and larval retention all covary with it -",
        "which makes it a useful covariate and a poor explanation."
      ),
      inputs = character(),
      neighbourhood = FALSE,
      outputs = function(spec) spec$name %||% "shore_dist"
    )
  )
}

#' Add the configured derived covariates to the covariate grid
#'
#' Runs each `covariates.derivoce` step in order, passing its fields straight
#' through to the derivoce function it names. Steps see the columns the earlier
#' ones produced, so they chain: a `current_speed` step followed by a
#' `horizontal_gradient` step on `speed` reproduces the original pipeline's
#' `uv_grad`.
#'
#' This runs on the **covariate grid**, before stations are matched to it, because
#' a gradient or a front is a property of the field and cannot be recovered from
#' scattered station points. Everything downstream then treats the results as
#' ordinary covariate columns: [attach_covariates()] matches them to stations,
#' [covariate_grid()] carries them onto the projection grid, and they are picked
#' up as predictors automatically. Contrast [add_derived_covariates()], which adds
#' `jday` to a table of observations and needs one date per row rather than a grid.
#'
#' Three consequences are worth stating plainly, since each one costs data:
#'
#' * Lags, integrals, and temporal gradients are undefined for the first time
#'   step(s) of the record, so stations in those months are dropped when covariates
#'   are matched, and the earliest month's projection has nothing to predict on.
#' * A step reading a point's surroundings is undefined on the edge of the study
#'   area, where the point has no complete neighbourhood. That border is lost from
#'   both the training stations and the projected maps, so a study area drawn to
#'   just contain the stations will lose the outermost ones.
#' * A neighbourhood step computed from a variable that was upsampled from a
#'   coarser product measures the source grid rather than the ocean. Those steps
#'   warn when their input is one of the upsampled variables recorded by
#'   [fetch_covariates()].
#'
#' @param env_dat covariate data from [fetch_covariates()]
#' @param config a config list, as returned by `load_config()`
#' @param bathy optional static bathymetry `SpatRaster` from
#'   [datamatch::fetch_bathymetry()], needed only by steps reading a depth column
#' @return `env_dat` with one column per derived covariate added
#' @examples
#' \dontrun{
#' env_dat <- fetch_covariates(config)
#' env_dat <- add_derivoce_covariates(env_dat, config)
#' }
#' @seealso [derivoce_covariates()] for the step types and the columns they produce
#' @export
add_derivoce_covariates <- function(env_dat, config, bathy = NULL) {
  specs <- config$covariates$derivoce
  if (length(specs) == 0) return(env_dat)

  if (!requireNamespace("derivoce", quietly = TRUE)) {
    stop("The 'derivoce' package is required for covariates.derivoce. ",
         "Install it with remotes::install_github('chross22/derivoce').",
         call. = FALSE)
  }

  specs <- lapply(specs, normalize_derivoce_spec)
  catalog <- derivoce_covariates()

  # Which variables were rendered onto a finer grid than their own, so a step
  # reading a neighbourhood can say so. Carried across explicitly because the
  # attribute does not survive every column-wise operation below.
  upsampled <- attr(env_dat, "upsampled")

  borrowed <- borrow_bathymetry(specs, env_dat, bathy)
  env_dat <- borrowed$env_dat

  for (spec in specs) {
    entry <- catalog[[spec$type]]
    fun <- getExportedValue("derivoce", spec$type)
    check_derivoce_args(spec, fun)
    warn_upsampled_inputs(spec, entry, upsampled)

    message("  ", spec$type, " -> ", paste(entry$outputs(spec), collapse = ", "))
    env_dat <- do.call(fun, c(list(env_dat), spec[names(spec) != "type"]))
  }

  # The grid leaves carrying exactly the covariates it arrived with, plus the
  # derived ones: bathymetry is attached to stations and to the projection grid
  # later, and would otherwise arrive there twice.
  if (length(borrowed$added) > 0) {
    env_dat <- env_dat[setdiff(names(env_dat), borrowed$added)]
  }
  attr(env_dat, "upsampled") <- upsampled
  env_dat
}

#' Normalize one derivoce step specification
#'
#' A step is a mapping of `type` plus the arguments for that type. A bare string
#' is accepted as shorthand for a step with no arguments, so `- distance_to_shore`
#' reads as it should.
#'
#' @param spec one entry of `covariates.derivoce`
#' @return the spec as a list with a validated `type` and vector-valued fields
#' @keywords internal
normalize_derivoce_spec <- function(spec) {
  if (is.character(spec) && length(spec) == 1) spec <- list(type = spec)

  known <- names(derivoce_covariates())
  if (is.null(spec$type)) {
    stop("Every covariates.derivoce entry needs a 'type'.\nAvailable: ",
         paste(known, collapse = ", "), call. = FALSE)
  }
  if (!(spec$type %in% known)) {
    stop("Unknown covariates.derivoce type '", spec$type, "'.\nAvailable: ",
         paste(known, collapse = ", "), call. = FALSE)
  }

  # YAML gives a list rather than a vector for any sequence it cannot simplify;
  # derivoce takes vectors.
  spec[] <- lapply(spec, function(value) if (is.list(value)) unlist(value) else value)
  spec
}

#' Covariate columns a derivoce step reads
#'
#' @param spec a normalized step specification
#' @param entry the matching [derivoce_covariates()] entry
#' @return character vector of covariate column names the step needs present
#' @keywords internal
derivoce_inputs <- function(spec, entry) {
  values <- lapply(names(entry$inputs), function(field) {
    value <- spec[[field]] %||% entry$inputs[[field]]
    if (identical(value, "")) {
      stop("covariates.derivoce: step '", spec$type, "' needs '", field,
           "' to name the covariate(s) it is computed from.", call. = FALSE)
    }
    value
  })
  values <- unlist(values)
  as.character(values[!is.na(values)])
}

#' Column names the configured derivoce steps will produce
#'
#' Known before a run, which is what lets `covariates.log_transform` name a
#' derived covariate and what lets the config be validated without fetching
#' anything.
#'
#' @param config a parsed config list
#' @return character vector of derived column names, in the order produced
#' @keywords internal
derivoce_names <- function(config) {
  specs <- config$covariates$derivoce
  if (length(specs) == 0) return(character())

  catalog <- derivoce_covariates()
  names <- lapply(specs, function(spec) {
    spec <- normalize_derivoce_spec(spec)
    catalog[[spec$type]]$outputs(spec)
  })
  as.character(unlist(names))
}

#' Check a step's fields against the derivoce function it names
#'
#' Deferred to run time rather than config validation, since it needs derivoce
#' itself and a config may be validated where derivoce is not installed.
#'
#' @param spec a normalized step specification
#' @param fun the derivoce function the step names
#' @return `TRUE` invisibly; errors listing the accepted arguments otherwise
#' @keywords internal
check_derivoce_args <- function(spec, fun) {
  accepted <- setdiff(names(formals(fun)), "env_dat")
  unknown <- setdiff(names(spec), c("type", accepted))
  if (length(unknown) > 0) {
    stop("covariates.derivoce: step '", spec$type, "' has no argument(s) ",
         paste(unknown, collapse = ", "), ".\nAccepted: ",
         paste(accepted, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

#' Warn when a neighbourhood step reads an upsampled variable
#'
#' @param spec a normalized step specification
#' @param entry the matching [derivoce_covariates()] entry
#' @param upsampled variables recorded as upsampled by [fetch_covariates()]
#' @return `NULL`, invisibly
#' @keywords internal
warn_upsampled_inputs <- function(spec, entry, upsampled) {
  if (!isTRUE(entry$neighbourhood) || length(upsampled) == 0) {
    return(invisible(NULL))
  }
  affected <- intersect(derivoce_inputs(spec, entry), upsampled)
  if (length(affected) == 0) return(invisible(NULL))

  warning(spec$type, " reads ", paste(affected, collapse = ", "),
          ", which was upsampled from a coarser product: the result is flat ",
          "inside each source cell and spikes at its edges, which describes the ",
          "source grid rather than the ocean. Compute it from a variable at its ",
          "native resolution, or set covariates.grid to 'coarsest'.",
          call. = FALSE)
  invisible(NULL)
}

#' Temporarily attach the bathymetry columns derivoce steps read
#'
#' Bathymetry reaches stations and the projection grid on its own, both after
#' this point, so a step reading a depth column has to be given one here.
#'
#' @param specs normalized step specifications
#' @param env_dat covariate data from [fetch_covariates()]
#' @param bathy a bathymetry `SpatRaster`, or `NULL`
#' @return `list(env_dat=, added=)`, where `added` names the borrowed columns
#' @keywords internal
borrow_bathymetry <- function(specs, env_dat, bathy) {
  catalog <- derivoce_covariates()
  wanted <- unlist(lapply(specs, function(spec) {
    derivoce_inputs(spec, catalog[[spec$type]])
  }))
  needed <- intersect(setdiff(unique(wanted), names(env_dat)),
                      names(bathymetry_covariates()))

  if (length(needed) == 0) return(list(env_dat = env_dat, added = character()))
  if (is.null(bathy)) {
    stop("covariates.derivoce needs ", paste(needed, collapse = ", "),
         " on the covariate grid, but no bathymetry was fetched. Add ",
         paste(needed, collapse = ", "), " to covariates.bathymetry.",
         call. = FALSE)
  }

  list(env_dat = datamatch::attach_bathymetry(env_dat, bathy, needed),
       added = needed)
}

#' Validate the derivoce block
#'
#' Walks the steps in order, so a step may read what an earlier one produced and
#' an out-of-order config is reported as a missing covariate rather than failing
#' partway through a run.
#'
#' @param config a parsed config list
#' @return `TRUE` invisibly; errors otherwise
#' @keywords internal
validate_derivoce <- function(config) {
  specs <- config$covariates$derivoce
  if (length(specs) == 0) return(invisible(TRUE))

  catalog <- derivoce_covariates()
  available <- c(config$covariates$selected, config$covariates$bathymetry,
                 names(config$covariates$copernicus))

  for (raw in specs) {
    spec <- normalize_derivoce_spec(raw)
    entry <- catalog[[spec$type]]

    missing_fields <- setdiff(entry$required, names(spec))
    if (length(missing_fields) > 0) {
      stop("covariates.derivoce: step '", spec$type, "' needs ",
           paste(missing_fields, collapse = ", "), ".", call. = FALSE)
    }

    unknown <- setdiff(derivoce_inputs(spec, entry), available)
    if (length(unknown) > 0) {
      stop("covariates.derivoce: step '", spec$type, "' reads ",
           paste(unknown, collapse = ", "),
           ", which no earlier step selects or produces.\nAvailable at that ",
           "point: ", paste(available, collapse = ", "), call. = FALSE)
    }

    produced <- entry$outputs(spec)
    clash <- intersect(produced, available)
    if (length(clash) > 0) {
      stop("covariates.derivoce: step '", spec$type, "' would overwrite ",
           paste(clash, collapse = ", "),
           ". Give it a different 'name' or 'suffix'.", call. = FALSE)
    }
    available <- c(available, produced)
  }
  invisible(TRUE)
}
