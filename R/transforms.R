#' Covariate transformations available in the recipe
#'
#' Which transformation a covariate needs is a modeling choice, so it is config
#' rather than code. The original applied `log(abs(x))` to a hardcoded trio of
#' chlorophyll, integrated chlorophyll, and bathymetry
#' (`original/buildZoopModel.R:134-136`).
#'
#' Two properties decide what a transform can safely be given:
#'
#' * `folds_sign` marks the transforms that take `abs(x)` first, because they are
#'   undefined for negative input. That is right for a magnitude stored with a
#'   sign convention — bathymetry is negative depth — and wrong for a genuinely
#'   signed covariate, where it maps `-2` and `2` onto the same value. Derived
#'   covariates make the second case common: a temporal gradient, a vertical
#'   gradient, and the current components are all signed. A transform warns when
#'   the column it is given actually holds both signs.
#' * `undefined_at_zero` marks `log` and `log10`, which return `-Inf` there.
#'   Zeros are ordinary in chlorophyll and in any derived integral that starts at
#'   zero, so this is checked against the data rather than trusted.
#'
#' `boxcox` and `yeojohnson` estimate their parameter from the data instead of
#' applying a fixed function, so they are recipe steps rather than a function of
#' `x`. Box-Cox requires strictly positive input; Yeo-Johnson does not, which
#' makes it the one estimated option that suits a signed covariate.
#'
#' @return a named list, one entry per transform, each with `label`,
#'   `description`, `folds_sign`, `undefined_at_zero`, and either `fn` (applied
#'   directly) or `step` (a `recipes` step function)
#' @examples
#' names(covariate_transforms())
#' covariate_transforms()$log1p$description
#' @references
#' Box GEP, Cox DR (1964). An analysis of transformations. *Journal of the Royal
#' Statistical Society: Series B* **26**(2), 211-252.
#' \doi{10.1111/j.2517-6161.1964.tb00553.x} — `boxcox`
#'
#' Yeo I-K, Johnson RA (2000). A new family of power transformations to improve
#' normality or symmetry. *Biometrika* **87**(4), 954-959.
#' \doi{10.1093/biomet/87.4.954} — `yeojohnson`
#'
#' Field JG, Clarke KR, Warwick RM (1982). A practical strategy for analysing
#' multispecies distribution patterns. *Marine Ecology Progress Series* **8**,
#' 37-52. \doi{10.3354/meps008037} — the fourth root as the plankton standard
#' @export
covariate_transforms <- function() {
  list(
    log1p = list(
      label = "log(1 + |x|)",
      description = paste(
        "The default, and what `log_transform` has always meant here. Defined at",
        "zero, unlike log and log10, which is why it is the one to reach for on",
        "chlorophyll and on integrals that start at zero."
      ),
      folds_sign = TRUE, undefined_at_zero = FALSE,
      fn = function(x) log1p(abs(x))
    ),
    log = list(
      label = "natural log",
      description = paste(
        "Natural log of the magnitude. Compresses covariates spanning orders of",
        "magnitude, and is what to use when the coefficient should read as a",
        "proportional change. Undefined at zero."
      ),
      folds_sign = TRUE, undefined_at_zero = TRUE,
      fn = function(x) log(abs(x))
    ),
    log10 = list(
      label = "log base 10",
      description = paste(
        "As natural log, on a scale that reads directly as orders of magnitude.",
        "Undefined at zero."
      ),
      folds_sign = TRUE, undefined_at_zero = TRUE,
      fn = function(x) log10(abs(x))
    ),
    sqrt = list(
      label = "square root",
      description = paste(
        "A milder compression than the logs, defined at zero. The usual first",
        "choice for counts and for right-skewed concentrations that include zeros."
      ),
      folds_sign = TRUE, undefined_at_zero = FALSE,
      fn = function(x) sqrt(abs(x))
    ),
    fourth_root = list(
      label = "fourth root",
      description = paste(
        "Between the square root and the logs in strength, and standard in",
        "plankton work for exactly that reason: it pulls in a long right tail",
        "without the logs' trouble at zero."
      ),
      folds_sign = TRUE, undefined_at_zero = FALSE,
      fn = function(x) abs(x)^0.25
    ),
    boxcox = list(
      label = "Box-Cox",
      description = paste(
        "Estimates the power that best symmetrizes each covariate rather than",
        "assuming one. Requires strictly positive input, so it cannot take a",
        "covariate with zeros or a signed one - use yeojohnson there."
      ),
      folds_sign = FALSE, undefined_at_zero = TRUE,
      step = function(rec, vars) recipes::step_BoxCox(rec, dplyr::all_of(vars))
    ),
    yeojohnson = list(
      label = "Yeo-Johnson",
      description = paste(
        "Box-Cox extended to zero and negative values, so it is the estimated",
        "transform for signed covariates - gradients, current components,",
        "anomalies - which the fixed transforms above can only handle by",
        "discarding the sign."
      ),
      folds_sign = FALSE, undefined_at_zero = FALSE,
      step = function(rec, vars) recipes::step_YeoJohnson(rec, dplyr::all_of(vars))
    )
  )
}

#' Transformations a config applies, as a named list
#'
#' Resolves the older `covariates.log_transform` onto the `covariates.transform`
#' block, so a config written before there was a choice keeps working and means
#' what it always meant.
#'
#' @param config a parsed config list
#' @return a named list of transform name to covariate names, possibly empty
#' @keywords internal
covariate_transform_spec <- function(config) {
  spec <- config$covariates$transform %||% list()
  spec <- lapply(spec, function(vars) as.character(unlist(vars)))

  legacy <- as.character(unlist(config$covariates$log_transform %||% character()))
  if (length(legacy) > 0) {
    spec$log1p <- union(spec$log1p %||% character(), legacy)
  }
  spec[lengths(spec) > 0]
}

#' Check a transform against the values it will be given
#'
#' Both checks need the data, so they happen where the recipe is built rather
#' than at config load: whether a covariate holds zeros or both signs is not
#' knowable from its name.
#'
#' @param values the covariate's values
#' @param covariate the covariate's name, for the message
#' @param name the transform's name
#' @param entry the matching [covariate_transforms()] entry
#' @return `TRUE` invisibly; errors on an undefined transform, warns on a folded
#'   sign
#' @keywords internal
check_transform_input <- function(values, covariate, name, entry) {
  finite <- values[is.finite(values)]
  if (length(finite) == 0) return(invisible(TRUE))

  if (isTRUE(entry$undefined_at_zero) && any(finite == 0)) {
    stop("covariates.transform: '", name, "' is undefined at zero, and ",
         covariate, " has ", sum(finite == 0), " zero value(s).\n",
         "Use log1p, sqrt, or fourth_root, which are defined there.",
         call. = FALSE)
  }
  if (isTRUE(entry$folds_sign) && any(finite < 0) && any(finite > 0)) {
    warning("covariates.transform: '", name, "' takes abs(", covariate,
            ") first, but ", covariate, " holds both signs, so equal and ",
            "opposite values become the same predictor. That is right for a ",
            "magnitude stored as negative, like depth, and wrong for a signed ",
            "quantity like a gradient - use yeojohnson for those.",
            call. = FALSE)
  }
  invisible(TRUE)
}

#' Validate the transform block
#'
#' @param config a parsed config list
#' @param available covariate names a transform may name
#' @return `TRUE` invisibly; errors otherwise
#' @keywords internal
validate_transforms <- function(config, available) {
  spec <- covariate_transform_spec(config)
  if (length(spec) == 0) return(invisible(TRUE))

  catalog <- covariate_transforms()
  unknown <- setdiff(names(spec), names(catalog))
  if (length(unknown) > 0) {
    stop("Unknown transform(s) in covariates.transform: ",
         paste(unknown, collapse = ", "),
         "\nAvailable: ", paste(names(catalog), collapse = ", "), call. = FALSE)
  }

  for (name in names(spec)) {
    missing <- setdiff(spec[[name]], available)
    if (length(missing) > 0) {
      stop("covariates.transform$", name, " names covariates that are not ",
           "selected: ", paste(missing, collapse = ", "), call. = FALSE)
    }
  }

  # One transform per covariate. Two would apply in list order, which is not a
  # thing anyone means to ask for.
  all_vars <- unlist(spec, use.names = FALSE)
  repeated <- unique(all_vars[duplicated(all_vars)])
  if (length(repeated) > 0) {
    stop("covariates.transform applies more than one transform to: ",
         paste(repeated, collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}
