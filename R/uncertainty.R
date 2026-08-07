#' Projection uncertainty settings
#'
#' A projected map is a surface of point estimates, and a point estimate on its
#' own invites more confidence than it has earned. Two different things can be
#' wrong with a cell, and they need separate answers because a cell can be
#' badly affected by one and untouched by the other:
#'
#' * **The fit could have been different.** Refit on slightly different data and
#'   the surface moves. [ensemble_spread()] measures how much.
#' * **The cell may be somewhere the model has never seen.**
#'   [novelty_surface()] is the one that catches this, and the spread cannot: a
#'   narrow interval means the members agree, not that they are right. Where the
#'   covariates are off the end of the training data, members can agree
#'   perfectly and all be extrapolating.
#'
#' The two do not track each other, and neither substitutes for the other. They
#' often move together — a resampled member's training range differs from the
#' full model's, so cells near the edge tend to be both novel and unstable — but
#' a confident prediction over a novel cell is exactly the case a spread-only
#' map reports as trustworthy. Read both.
#'
#' Off by default. On a real grid over a decade the extra prediction passes are
#' a real multiplier, and most runs are iterations that only want the mean
#' surface.
#'
#' ```yaml
#' projection:
#'   uncertainty: true          # or the block below, for the non-defaults
#'   uncertainty:
#'     method: folds            # or: bootstrap
#'     replicates: 100          # bootstrap only
#'     level: 0.9               # interval width
#'     novelty: true
#' ```
#'
#' @param config a config list, as returned by `load_config()`
#' @return `NULL` when off, otherwise a list with `method`, `replicates`,
#'   `level`, and `novelty`
#' @examples
#' config <- load_config(
#'   system.file("configs/mock_test.yaml", package = "taupatch")
#' )
#' uncertainty_settings(config)                      # NULL: off by default
#'
#' config$projection$uncertainty <- TRUE
#' uncertainty_settings(config)
#'
#' config$projection$uncertainty <- list(method = "bootstrap", level = 0.95)
#' uncertainty_settings(config)
#' @seealso [novelty_surface()], [ensemble_spread()]
#' @export
uncertainty_settings <- function(config) {
  spec <- config$projection$uncertainty
  if (is.null(spec) || isFALSE(spec)) return(NULL)
  if (isTRUE(spec)) spec <- list()

  if (!is.list(spec)) {
    stop("projection.uncertainty must be true, false, or a block of settings.",
         call. = FALSE)
  }

  settings <- list(
    method = spec$method %||% "folds",
    replicates = spec$replicates %||% 100L,
    level = spec$level %||% 0.9,
    novelty = !isFALSE(spec$novelty)
  )

  if (!(settings$method %in% c("folds", "bootstrap"))) {
    stop("projection.uncertainty.method must be 'folds' or 'bootstrap', got '",
         settings$method, "'.", call. = FALSE)
  }
  if (!is.numeric(settings$level) || settings$level <= 0 || settings$level >= 1) {
    stop("projection.uncertainty.level must be between 0 and 1, got ",
         settings$level, ".", call. = FALSE)
  }
  settings$replicates <- as.integer(settings$replicates)
  if (is.na(settings$replicates) || settings$replicates < 2) {
    stop("projection.uncertainty.replicates must be at least 2.", call. = FALSE)
  }
  settings
}

#' Validate the projection uncertainty block
#'
#' @param config a parsed config list
#' @return `TRUE` invisibly; errors otherwise
#' @keywords internal
validate_uncertainty <- function(config) {
  settings <- uncertainty_settings(config)
  if (is.null(settings)) return(invisible(TRUE))

  # Reusing the cross-validation folds means the interval is built from
  # `model.cv_folds` members, and that number is what limits how far into the
  # tail the quantiles can honestly reach.
  if (identical(settings$method, "folds")) {
    folds <- config$model$cv_folds %||% 10
    if (folds < 3) {
      stop("projection.uncertainty with method 'folds' needs at least 3 ",
           "model.cv_folds to have anything to spread over; got ", folds,
           ".\nRaise cv_folds, or use method: bootstrap.", call. = FALSE)
    }
  }
  invisible(TRUE)
}

#' The fitted models an interval is built from
#'
#' Cross-validation already fits one model per fold and then throws them away.
#' Asking `tune` to hand them back costs nothing, so the default ensemble is
#' free: the only extra work a projection does is predicting from each member.
#'
#' `bootstrap` refits instead, which does cost, and buys the one thing folds
#' cannot give — enough members for a quantile to mean something. Ten folds
#' support a spread; they do not support a 95% interval, because the 2.5th
#' percentile of ten numbers is the smallest of them.
#'
#' @param resampled the `tune::fit_resamples()` result, fitted with
#'   `control_resamples(extract = )`
#' @param workflow the workflow to refit, for `bootstrap`
#' @param model_data the data to refit on, for `bootstrap`
#' @param settings from [uncertainty_settings()]
#' @return a list of fitted workflows
#' @keywords internal
projection_ensemble <- function(resampled, workflow, model_data, settings) {
  if (identical(settings$method, "bootstrap")) {
    message("  fitting ", settings$replicates, " bootstrap models for the ",
            "projection interval")
    resamples <- rsample::bootstraps(model_data, times = settings$replicates)
    members <- lapply(resamples$splits, function(split) {
      tryCatch(parsnip::fit(workflow, data = rsample::analysis(split)),
               error = function(e) NULL)
    })
    return(Filter(Negate(is.null), members))
  }

  # The extract column is one row per fold, each holding the fitted workflow.
  extracts <- resampled$.extracts
  if (is.null(extracts)) return(list())

  members <- lapply(extracts, function(fold) {
    if (is.null(fold) || !(".extracts" %in% names(fold))) return(NULL)
    fold$.extracts[[1]]
  })
  Filter(function(x) inherits(x, "workflow"), members)
}

#' Spread of an ensemble's predictions, per cell
#'
#' Every member predicts every cell; this reduces those to a standard deviation
#' and an interval. The point estimate is left alone — it stays the prediction
#' of the model fitted on all the data, so turning uncertainty on adds columns
#' to a map without moving it.
#'
#' @section What it does not cover:
#' This is the spread of refits on resampled training data. It is a **lower
#' bound** on how wrong a cell can be, and three things are outside it
#' entirely: covariates that are themselves estimates carrying their own error,
#' the possibility that the model form is wrong, and extrapolation. The last is
#' the one that bites, because agreement between members is not evidence: they
#' were all trained on the same data and can walk off the end of it together.
#' [novelty_surface()] is reported beside this rather than instead of it for
#' that reason.
#'
#' @section Reading the interval:
#' It is a percentile range over the members, not a calibrated confidence
#' interval, and with the default `folds` method there are only
#' `model.cv_folds` of them. Ten members cannot support a 95% interval — its
#' 2.5th percentile is the smallest of the ten — which is why `level` defaults
#' to 0.9 and why `method: bootstrap` exists for when the number needs to mean
#' something.
#'
#' The point estimate is not guaranteed to fall inside it. The estimate comes
#' from the model fitted on all the data and the interval from models fitted on
#' parts of it, so these are two different quantities; on the package's mock
#' run a 90% interval contains the point estimate for about 90% of cells, which
#' is the behaviour to expect rather than a fault.
#'
#' @param ensemble a list of fitted workflows, from [projection_ensemble()]
#' @param newdata the cells to predict
#' @param level interval width, e.g. 0.9 for a 5th-to-95th percentile range
#' @return a data frame of `suitability_sd`, `suitability_lower`,
#'   `suitability_upper`, and `n_members`; `NULL` if the ensemble is empty
#' @seealso [novelty_surface()], which answers the question this one cannot
#' @keywords internal
ensemble_spread <- function(ensemble, newdata, level = 0.9) {
  if (length(ensemble) == 0) return(NULL)

  predictions <- lapply(ensemble, function(member) {
    tryCatch(
      stats::predict(member, new_data = newdata, type = "prob")$.pred_patch,
      error = function(e) NULL
    )
  })
  predictions <- Filter(Negate(is.null), predictions)
  if (length(predictions) < 2) return(NULL)

  matrix_of <- do.call(cbind, predictions)
  tail <- (1 - level) / 2

  data.frame(
    suitability_sd = apply(matrix_of, 1, stats::sd, na.rm = TRUE),
    suitability_lower = apply(matrix_of, 1, stats::quantile, probs = tail,
                              na.rm = TRUE, names = FALSE),
    suitability_upper = apply(matrix_of, 1, stats::quantile, probs = 1 - tail,
                              na.rm = TRUE, names = FALSE),
    n_members = ncol(matrix_of)
  )
}

#' How far outside the training data each cell sits
#'
#' The multivariate environmental similarity surface of Elith, Kearney and
#' Phillips (2010). For each predictor it asks where a cell's value falls in the
#' distribution of values the model was trained on, and the cell takes the worst
#' answer across predictors — one predictor far outside its training range is
#' enough to make a prediction an extrapolation, however ordinary the rest look.
#'
#' The scale runs to 100 and is readable directly:
#'
#' * **100** — at the median of the training data for every predictor.
#' * **0 to 100** — inside the training range on all predictors; lower means
#'   nearer an edge of it.
#' * **below 0** — outside the training range on at least one predictor. The
#'   magnitude is how far outside, as a percentage of the training range, so
#'   `-50` is half a range beyond the edge. **These cells are extrapolation**,
#'   and the model has no evidence for what it says there.
#'
#' `novel_variable` names the predictor responsible, which is the actionable
#' half: "this coast is extrapolated" is a shrug, and "this coast is extrapolated
#' because its chlorophyll is higher than anything a station saw" is a decision
#' about whether to widen the training window or clip the map.
#'
#' @param grid the cells to score, with one column per predictor
#' @param model_data the data the model was fitted on
#' @param predictors predictor column names
#' @return a data frame of `novelty` and `novel_variable`, one row per cell
#' @examples
#' train <- data.frame(SST = c(4, 8, 12, 16), CHL = c(0.2, 0.5, 1.0, 2.0))
#' grid <- data.frame(SST = c(10, 25), CHL = c(0.6, 0.6))
#'
#' # The second cell is warmer than any training station, and says so.
#' novelty_surface(grid, train, c("SST", "CHL"))
#' @references
#' Elith J, Kearney M, Phillips S (2010). The art of modelling range-shifting
#' species. *Methods in Ecology and Evolution* **1**(4), 330-342.
#' \doi{10.1111/j.2041-210X.2010.00036.x}
#' @seealso [ensemble_spread()], which answers a different question about the
#'   same cell
#' @export
novelty_surface <- function(grid, model_data, predictors) {
  predictors <- intersect(predictors, intersect(names(grid), names(model_data)))
  if (length(predictors) == 0) {
    return(data.frame(novelty = rep(NA_real_, nrow(grid)),
                      novel_variable = rep(NA_character_, nrow(grid)),
                      stringsAsFactors = FALSE))
  }

  similarity <- vapply(predictors, function(v) {
    variable_similarity(grid[[v]], model_data[[v]])
  }, numeric(nrow(grid)))
  # vapply drops to a vector when the grid has one row, which then indexes
  # wrongly below.
  similarity <- matrix(similarity, nrow = nrow(grid),
                       dimnames = list(NULL, predictors))

  worst <- apply(similarity, 1, function(row) {
    if (all(is.na(row))) return(NA_integer_)
    which.min(row)
  })

  data.frame(
    novelty = apply(similarity, 1, min, na.rm = FALSE),
    novel_variable = ifelse(is.na(worst), NA_character_, predictors[worst]),
    stringsAsFactors = FALSE
  )
}

#' Similarity of values to a training distribution, for one predictor
#'
#' The per-variable half of [novelty_surface()]. Negative below the training
#' minimum and above its maximum, scaled by the training range; inside, twice
#' the distance to the nearer tail in percentile terms, so the median scores 100.
#'
#' @param values the values to score
#' @param train the training values for the same predictor
#' @return a numeric vector the length of `values`
#' @keywords internal
variable_similarity <- function(values, train) {
  train <- sort(train[is.finite(train)])
  n <- length(train)
  if (n == 0) return(rep(NA_real_, length(values)))

  low <- train[1]
  high <- train[n]
  span <- high - low

  # A predictor that never varied in training carries no information about
  # what is ordinary, so it can only say same-or-not.
  if (span == 0) {
    return(ifelse(is.na(values), NA_real_, ifelse(values == low, 100, -Inf)))
  }

  # Percentile of each value within the training distribution. findInterval
  # with left.open counts the training values strictly below, which is the
  # count this needs and is a binary search rather than a full comparison
  # against every training row - the difference between a grid that scores in
  # a moment and one that does not.
  below <- findInterval(values, train, left.open = TRUE)
  percentile <- 100 * below / n

  out <- ifelse(
    percentile == 0, 100 * (values - low) / span,
    ifelse(percentile <= 50, 2 * percentile,
           ifelse(percentile < 100, 2 * (100 - percentile),
                  100 * (high - values) / span))
  )
  out[is.na(values)] <- NA_real_
  out
}

#' Summarise a novelty surface for the run log
#'
#' A map is easy not to look at. This is the one line that says whether it
#' needed looking at.
#'
#' @param novelty the `novelty` column from [novelty_surface()]
#' @param novel_variable the matching `novel_variable` column
#' @return a single string, or `NULL` when nothing is extrapolated
#' @keywords internal
novelty_message <- function(novelty, novel_variable) {
  outside <- which(!is.na(novelty) & novelty < 0)
  if (length(outside) == 0) return(NULL)

  share <- round(100 * length(outside) / sum(!is.na(novelty)))
  culprits <- sort(table(novel_variable[outside]), decreasing = TRUE)

  paste0(length(outside), " of ", sum(!is.na(novelty)), " cells (", share,
         "%) are outside the training range, driven by ",
         paste0(names(culprits), " (", as.integer(culprits), ")",
                collapse = ", "))
}
