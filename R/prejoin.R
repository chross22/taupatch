#' Per-covariate steps applied before products are joined
#'
#' Copernicus products arrive on different grids, and [fetch_covariates()]
#' reconciles them by joining everything onto one. That join is all-or-nothing:
#' every covariate is either upsampled or left alone according to a single
#' `covariates.grid` choice, with no say in how.
#'
#' A `covariates.prejoin` block is that say. Each step names a covariate and
#' resamples it, or fills its gaps, *before* the join happens — so the join then
#' sees grids that already agree, and does nothing to them.
#'
#' The reason to want this is that the right treatment differs per covariate.
#' Ocean-colour chlorophyll is a 4 km optical retrieval full of cloud gaps;
#' physics is a 0.083 degree model with no gaps at all. Bringing chlorophyll up to
#' the physics grid by averaging is a defensible summary of values that were
#' really measured. Interpolating physics down to 4 km invents structure. One
#' global setting cannot express that, and the `upsampled` warning exists
#' precisely because the current join cannot either.
#'
#' The computation is [datamatch::upscale_grid()], [datamatch::downscale_grid()],
#' and [datamatch::fill_satellite_gaps()] throughout, which own it.
#'
#' @return a named list, one entry per step type, each with `label`,
#'   `description`, `targets` (the step fields naming covariates), and `fun`
#' @examples
#' names(prejoin_steps())
#' prejoin_steps()$upscale$description
#' @seealso [apply_prejoin_steps()], which runs the configured steps
#' @export
prejoin_steps <- function() {
  list(
    upscale = list(
      label = "Aggregate onto a coarser grid",
      description = paste(
        "Combines the source cells inside each target cell into one value. This",
        "is the direction that discards detail, which is the safe direction:",
        "every value in the result summarises values that were really measured.",
        "`method` chooses the summary - median resists the retrieval artefacts",
        "at cloud edges that make satellite chlorophyll's outliers one-sided."
      ),
      targets = c("covariate", "to"),
      fun = function(...) datamatch::upscale_grid(...)
    ),
    downscale = list(
      label = "Interpolate onto a finer grid",
      description = paste(
        "Puts a coarse field onto a finer grid. This direction invents values",
        "between the ones that were measured, so what it produces is an estimate",
        "and not a measurement. `nearest` replicates and is honest about being",
        "blocky; `bilinear` and `idw` are smooth and look more like data than",
        "they are."
      ),
      targets = c("covariate", "to"),
      fun = function(...) datamatch::downscale_grid(...)
    ),
    fill_gaps = list(
      label = "Fill gaps from another covariate",
      description = paste(
        "Substitutes a second covariate's value wherever the first is missing -",
        "the model equivalent where cloud blocked the satellite. The two are",
        "different measurements of the same quantity, so the result changes its",
        "statistical properties at the seam. A `<covariate>_source` column",
        "records which source each value came from."
      ),
      targets = c("covariate", "from"),
      fun = function(...) datamatch::fill_satellite_gaps(...)
    )
  )
}

#' Apply the configured pre-join steps to the fetched products
#'
#' Steps run in order, each against the product object holding the covariate it
#' names, so a later step sees what an earlier one produced.
#'
#' A step naming one covariate of a product that carries several splits it out
#' first. `datamatch::upscale_grid()` returns only the columns it was asked to
#' resample, so regridding chlorophyll in place would silently drop the other
#' plankton variables sharing its dataset. Splitting means the rest stay on their
#' own grid and reach the join intact.
#'
#' @param per_dataset a list of `sf` POINT objects, one per fetched product
#' @param config a config list, as returned by `load_config()`
#' @return a list of `sf` POINT objects, ready to join
#' @seealso [prejoin_steps()] for the step types
#' @export
apply_prejoin_steps <- function(per_dataset, config) {
  specs <- config$covariates$prejoin
  if (length(specs) == 0) return(per_dataset)

  catalog <- prejoin_steps()

  for (raw in specs) {
    spec <- normalize_prejoin_spec(raw)
    entry <- catalog[[spec$type]]

    owner <- prejoin_owner(per_dataset, spec$covariate, spec$type)
    per_dataset <- split_covariate(per_dataset, owner, spec$covariate)
    owner <- prejoin_owner(per_dataset, spec$covariate, spec$type)

    args <- spec[!(names(spec) %in% c("type", "covariate", "to", "from"))]

    if (spec$type == "fill_gaps") {
      source_index <- prejoin_owner(per_dataset, spec$from, spec$type)
      keep_source <- isTRUE(spec$keep_source)
      args$keep_source <- NULL

      message("  fill_gaps: ", spec$covariate, " <- ", spec$from)
      per_dataset[[owner]] <- do.call(entry$fun, c(
        list(per_dataset[[owner]], per_dataset[[source_index]],
             stats::setNames(spec$from, spec$covariate)),
        args
      ))

      # The source was fetched as a means rather than an end, and keeping it
      # would hand the model two near-identical predictors. Dropped unless the
      # config says otherwise, and said out loud either way.
      if (!keep_source) {
        message("    ", spec$from, " dropped from the join",
                " (keep_source: true to retain it)")
        per_dataset <- drop_covariate(per_dataset, source_index, spec$from)
      }
      next
    }

    to <- prejoin_target(per_dataset, spec$to)
    message("  ", spec$type, ": ", spec$covariate, " -> ",
            if (is.numeric(spec$to)) paste(spec$to, "degrees") else
              paste("the", spec$to, "grid"))
    per_dataset[[owner]] <- do.call(entry$fun, c(
      list(per_dataset[[owner]], to = to, vars = spec$covariate), args
    ))
  }

  Filter(function(x) length(datamatch::covariate_columns(x)) > 0, per_dataset)
}

#' Which fetched product carries a covariate
#'
#' @param per_dataset a list of `sf` POINT objects
#' @param covariate a covariate name
#' @param type the step type, for the error message
#' @return the index of the object holding it
#' @keywords internal
prejoin_owner <- function(per_dataset, covariate, type) {
  holds <- vapply(per_dataset,
                  function(x) covariate %in% datamatch::covariate_columns(x),
                  logical(1))
  if (!any(holds)) {
    available <- unlist(lapply(per_dataset, datamatch::covariate_columns))
    stop("covariates.prejoin: step '", type, "' names ", covariate,
         ", which no fetched product carries.\nAvailable: ",
         paste(available, collapse = ", "), call. = FALSE)
  }
  which(holds)[1]
}

#' Resolve a step's target grid
#'
#' A covariate name means "that covariate's grid", which is how a config says
#' "put chlorophyll where the physics is" without knowing what resolution the
#' physics happens to be. A number is a resolution in degrees.
#'
#' @param per_dataset a list of `sf` POINT objects
#' @param to a covariate name or a numeric resolution
#' @return an `sf` object or a number, as `datamatch` expects
#' @keywords internal
prejoin_target <- function(per_dataset, to) {
  if (is.numeric(to)) return(to)
  per_dataset[[prejoin_owner(per_dataset, to, "upscale/downscale")]]
}

#' Split one covariate out of the product carrying it
#'
#' A no-op when the product carries only that covariate.
#'
#' @param per_dataset a list of `sf` POINT objects
#' @param index which object to split
#' @param covariate the covariate to separate
#' @return `per_dataset` with the covariate as its own entry
#' @keywords internal
split_covariate <- function(per_dataset, index, covariate) {
  object <- per_dataset[[index]]
  others <- setdiff(datamatch::covariate_columns(object), covariate)
  if (length(others) == 0) return(per_dataset)

  geometry <- attr(object, "sf_column")
  time <- intersect(c("YEAR", "MONTH", "DAY"), names(object))

  per_dataset[[index]] <- object[c(time, others, geometry)]
  c(per_dataset, list(object[c(time, covariate, geometry)]))
}

#' Remove a covariate from the product carrying it
#'
#' @param per_dataset a list of `sf` POINT objects
#' @param index which object to take it from
#' @param covariate the covariate to drop
#' @return `per_dataset` without that column
#' @keywords internal
drop_covariate <- function(per_dataset, index, covariate) {
  object <- per_dataset[[index]]
  per_dataset[[index]] <- object[setdiff(names(object), covariate)]
  per_dataset
}

#' Normalize one pre-join step specification
#'
#' @param spec one entry of `covariates.prejoin`
#' @return the spec as a list with a validated `type`
#' @keywords internal
normalize_prejoin_spec <- function(spec) {
  known <- names(prejoin_steps())
  if (is.null(spec$type)) {
    stop("Every covariates.prejoin entry needs a 'type'.\nAvailable: ",
         paste(known, collapse = ", "), call. = FALSE)
  }
  if (!(spec$type %in% known)) {
    stop("Unknown covariates.prejoin type '", spec$type, "'.\nAvailable: ",
         paste(known, collapse = ", "), call. = FALSE)
  }
  spec[] <- lapply(spec, function(value) if (is.list(value)) unlist(value) else value)
  spec
}

#' Covariates a pre-join block removes from the join
#'
#' A `fill_gaps` source is fetched to fill another covariate, not to be a
#' predictor, so it does not survive the join unless asked to. Known before a run
#' so config validation can tell a covariate that will be there from one that
#' will not.
#'
#' @param config a parsed config list
#' @return character vector of covariate names
#' @keywords internal
prejoin_dropped <- function(config) {
  specs <- config$covariates$prejoin
  if (length(specs) == 0) return(character())

  dropped <- lapply(specs, function(raw) {
    spec <- normalize_prejoin_spec(raw)
    if (spec$type == "fill_gaps" && !isTRUE(spec$keep_source)) spec$from else NULL
  })
  as.character(unlist(dropped))
}

#' Validate the pre-join block
#'
#' @param config a parsed config list
#' @return `TRUE` invisibly; errors otherwise
#' @keywords internal
validate_prejoin <- function(config) {
  specs <- config$covariates$prejoin
  if (length(specs) == 0) return(invisible(TRUE))

  catalog <- prejoin_steps()
  selected <- config$covariates$selected

  if (length(selected) == 0) {
    stop("covariates.prejoin needs covariates.selected to name what it acts on.",
         call. = FALSE)
  }

  for (raw in specs) {
    spec <- normalize_prejoin_spec(raw)
    entry <- catalog[[spec$type]]

    for (field in entry$targets) {
      value <- spec[[field]]
      if (is.null(value)) {
        stop("covariates.prejoin: step '", spec$type, "' needs '", field, "'.",
             call. = FALSE)
      }
      # `to` may be a resolution in degrees rather than a covariate.
      if (field == "to" && is.numeric(value)) {
        if (value <= 0) {
          stop("covariates.prejoin: 'to' must be a positive resolution in ",
               "degrees, got ", value, ".", call. = FALSE)
        }
        next
      }
      if (!(value %in% selected)) {
        stop("covariates.prejoin: step '", spec$type, "' names ", value,
             ", which covariates.selected does not fetch.\nSelected: ",
             paste(selected, collapse = ", "), call. = FALSE)
      }
    }

    if (identical(spec$covariate, spec$to) || identical(spec$covariate, spec$from)) {
      stop("covariates.prejoin: step '", spec$type, "' names ", spec$covariate,
           " as both its subject and its target.", call. = FALSE)
    }
  }
  invisible(TRUE)
}
