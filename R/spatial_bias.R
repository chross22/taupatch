#' How much of the AUC is an artefact of where the stations are
#'
#' A cross-validated AUC is optimistic when the held-out patches sit closer to
#' the training patches than the held-out non-patches do. The model can then
#' score well by recognising *where* it has already been rather than *what*
#' makes a patch, and nothing in the ROC curve distinguishes the two.
#'
#' This is the spatial sorting bias of Hijmans (2012): the mean distance from
#' each held-out patch to the nearest training patch, over the same distance
#' for the held-out non-patches.
#'
#' \deqn{SSB = \frac{\overline{d}(\mathrm{held\ out\ patch},\ \mathrm{training\ patch})}{\overline{d}(\mathrm{held\ out\ non\ patch},\ \mathrm{training\ patch})}}
#'
#' * **Near 1** — held-out patches and non-patches are equally far from the
#'   training patches. The split is spatially fair and the AUC means what it
#'   appears to.
#' * **Near 0** — held-out patches are much closer to training patches than the
#'   non-patches are. **The AUC is inflated**, and by an amount this number
#'   does not tell you.
#'
#' It is a property of the *split*, not of the model. Every model type fitted on
#' the same folds gets the same value, which is the point: it says how much to
#' trust the comparison between them, not which of them won.
#'
#' @section Why an ECOMON run should look at it:
#' Survey stations are not scattered at random. They sit on transects, revisited
#' season after season, so a randomly held-out station usually has a near
#' neighbour in the training folds — often the same station in another year.
#' That is the situation this measures, and random `model.cv_folds` cannot avoid
#' it. A low value is an argument for spatially blocked folds, not for a
#' different model.
#'
#' @param model a fitted model from [fit_patch_model()] or
#'   [fit_patch_ensemble()], carrying `coordinates` and held-out `predictions`
#' @param geo whether to measure great-circle distances. `TRUE` by default,
#'   because the coordinates are longitude and latitude, and a degree of
#'   longitude is not a degree of latitude anywhere but the equator
#' @return a data frame with one row per fold and a `fold` of `"overall"` for
#'   the mean, carrying `patch_distance`, `non_patch_distance` and `ssb`
#' @examples
#' \dontrun{
#' model <- fit_patch_model(dat, config)
#' spatial_bias(model)
#' }
#' @references
#' Hijmans RJ (2012). Cross-validation of species distribution models: removing
#' spatial sorting bias and calibration with a null model. *Ecology* **93**(3),
#' 679-688. \doi{10.1890/11-0826.1}
#' @seealso [evaluation_table()], which reports the summary beside the AUC it
#'   qualifies
#' @export
spatial_bias <- function(model, geo = TRUE) {
  coordinates <- model$coordinates
  predictions <- model$predictions

  if (is.null(coordinates) || is.null(predictions) ||
      !all(c(".row", "id", "patch") %in% names(predictions))) {
    return(NULL)
  }

  folds <- split(seq_len(nrow(predictions)), predictions$id)
  rows <- lapply(names(folds), function(fold) {
    at <- folds[[fold]]
    held_out <- predictions$.row[at]
    is_patch <- predictions$patch[at] == "patch"

    # The reference is the training patches: every patch station except the
    # ones held out in this fold. A held-out patch that is close to one of them
    # is a patch the model has, in effect, already seen.
    all_patches <- predictions$.row[predictions$patch == "patch"]
    training <- setdiff(all_patches, held_out[is_patch])

    if (!any(is_patch) || !any(!is_patch) || length(training) == 0) {
      return(NULL)
    }

    out <- fancyfx::spatial_sorting_bias(
      presence = coordinates[held_out[is_patch], , drop = FALSE],
      absence = coordinates[held_out[!is_patch], , drop = FALSE],
      reference = coordinates[training, , drop = FALSE],
      geo = geo
    )
    data.frame(fold = fold, patch_distance = out[["presence"]],
               non_patch_distance = out[["absence"]], ssb = out[["ssb"]],
               stringsAsFactors = FALSE)
  })

  out <- do.call(rbind, Filter(Negate(is.null), rows))
  if (is.null(out) || nrow(out) == 0) return(NULL)

  # One number to report beside the AUC, and the folds it came from kept so a
  # single odd fold is visible rather than averaged into the answer.
  overall <- data.frame(
    fold = "overall",
    patch_distance = mean(out$patch_distance, na.rm = TRUE),
    non_patch_distance = mean(out$non_patch_distance, na.rm = TRUE),
    ssb = mean(out$ssb, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
  rbind(out, overall)
}

#' The one-line reading of a spatial sorting bias
#'
#' Written for the run log, where a bare ratio would be ignored. The thresholds
#' are conventional rather than derived — Hijmans (2012) offers no cutoff, and
#' presenting one as though he did would be worse than a rule of thumb labelled
#' as one.
#'
#' @param ssb the overall spatial sorting bias
#' @return a single string
#' @keywords internal
spatial_bias_note <- function(ssb) {
  if (is.na(ssb)) return("spatial sorting bias could not be computed")
  if (ssb >= 0.8) {
    return(paste0("spatial sorting bias ", signif(ssb, 2),
                  ": the folds are spatially fair"))
  }
  paste0("spatial sorting bias ", signif(ssb, 2),
         ": held-out patches sit closer to training patches than non-patches ",
         "do, so the AUC above is optimistic. Consider spatially blocked folds")
}

#' The single spatial sorting bias from a per-fold table
#'
#' @param bias the result of [spatial_bias()], or `NULL`
#' @return the overall ratio, or `NA_real_`
#' @keywords internal
overall_ssb <- function(bias) {
  if (is.null(bias) || !("fold" %in% names(bias))) return(NA_real_)
  value <- bias$ssb[bias$fold == "overall"]
  if (length(value) == 1) value else NA_real_
}
