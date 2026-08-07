#' Bootstrap intervals for the evaluation metrics
#'
#' Resampling gives a standard error for the metrics `tune` computes per fold,
#' and nothing at all for the rest. `pr_auc`, `tss` and `precision` are derived
#' from the pooled held-out predictions rather than averaged over folds, so the
#' fold structure is used up by the pooling and there is no per-fold spread left
#' to take. Those rows carried `NA`, which said "no uncertainty available" in a
#' column a reader will read as "no uncertainty".
#'
#' This resamples the pooled predictions with replacement and recomputes every
#' metric on each resample, so every row gets an interval and every interval
#' means the same thing.
#'
#' @section What the interval covers, and what it does not:
#' It is the sampling variability of **these predictions on these stations** —
#' how much the number would move if the survey had drawn a different set of
#' stations from the same population. It does not cover the variability of
#' refitting the model, which is what the per-fold `std_err` column reports.
#' The two are different quantities and are kept in different columns for that
#' reason; neither contains the other.
#'
#' @section The optimal cutoff moves too:
#' The TSS-maximising cutoff is estimated from the same predictions it is then
#' used to evaluate. Holding it fixed while bootstrapping would report the
#' metrics at that cutoff as more certain than they are, since a different
#' sample would have chosen a different cutoff. So each replicate re-derives its
#' own optimal cutoff and is scored at that, which folds the cutoff's own
#' instability into the interval — and `classification_threshold` gets an
#' interval of its own, which is worth reading before trusting a binarised map.
#'
#' @param predictions held-out predictions from resampling
#' @param cutoff the TSS-maximising cutoff, from [optimal_threshold()]
#' @param times how many bootstrap resamples
#' @param level interval width
#' @param seed optional seed, so a run's intervals are reproducible
#' @return a data frame of `metric`, `threshold_kind`, `lower`, `upper`, and
#'   `boot_n`, or `NULL` when the bootstrap cannot run
#' @examples
#' predictions <- data.frame(
#'   patch = factor(rep(c("patch", "non_patch"), c(20, 80)),
#'                  levels = c("patch", "non_patch")),
#'   .pred_patch = c(stats::runif(20, 0.4, 0.9), stats::runif(80, 0.05, 0.5))
#' )
#' bootstrap_evaluation(predictions, cutoff = 0.4, times = 50)
#' @seealso [evaluation_table()], which merges this into the reported table
#' @export
bootstrap_evaluation <- function(predictions, cutoff, times = 2000,
                                 level = 0.95, seed = NULL) {
  if (is.null(predictions) || !(".pred_patch" %in% names(predictions))) {
    return(NULL)
  }
  times <- as.integer(times)
  if (is.na(times) || times < 2) return(NULL)

  n <- nrow(predictions)
  truth <- predictions$patch
  probability <- predictions$.pred_patch
  if (n < 2 || length(unique(truth)) < 2) return(NULL)

  if (!is.null(seed)) {
    # Restored afterwards: a run's own seed governs the model, and the
    # evaluation should not silently move the stream everything after it draws
    # from.
    if (exists(".Random.seed", envir = globalenv())) {
      state <- get(".Random.seed", envir = globalenv())
      on.exit(assign(".Random.seed", state, envir = globalenv()), add = TRUE)
    }
    set.seed(seed)
  }

  # Preallocated rather than accumulated: a few thousand small data frames
  # rbound together costs more than every metric in the loop put together.
  columns <- c("roc_auc.none", "pr_auc.none",
               "sens.default", "spec.default", "tss.default", "precision.default",
               "sens.optimal", "spec.optimal", "tss.optimal", "precision.optimal",
               "classification_threshold.optimal")
  drawn <- matrix(NA_real_, nrow = times, ncol = length(columns),
                  dimnames = list(NULL, columns))

  is_patch <- truth == "patch"
  usable <- 0L

  for (i in seq_len(times)) {
    index <- sample.int(n, n, replace = TRUE)
    boot_patch <- is_patch[index]
    # A resample can miss the rare class entirely, and every metric here is
    # undefined without both. Dropped rather than counted as a zero, which
    # would drag the lower bound down for a reason that is not about the model.
    if (!any(boot_patch) || all(boot_patch)) next

    boot_probability <- probability[index]
    boot_truth <- truth[index]
    boot_cutoff <- best_cutoff(boot_patch, boot_probability)

    usable <- usable + 1L
    drawn[usable, "roc_auc.none"] <-
      safe_auc(yardstick::roc_auc_vec, boot_truth, boot_probability)
    drawn[usable, "pr_auc.none"] <-
      safe_auc(yardstick::pr_auc_vec, boot_truth, boot_probability)

    drawn[usable, 3:6] <-
      confusion_metrics(boot_probability >= 0.5, boot_patch)
    if (!is.na(boot_cutoff)) {
      drawn[usable, 7:10] <-
        confusion_metrics(boot_probability >= boot_cutoff, boot_patch)
    }
    drawn[usable, "classification_threshold.optimal"] <- boot_cutoff
  }

  if (usable < 2) return(NULL)
  drawn <- drawn[seq_len(usable), , drop = FALSE]

  tail <- (1 - level) / 2
  bounds <- apply(drawn, 2, function(values) {
    values <- values[is.finite(values)]
    if (length(values) < 2) return(c(NA_real_, NA_real_, length(values)))
    c(stats::quantile(values, tail, names = FALSE),
      stats::quantile(values, 1 - tail, names = FALSE),
      length(values))
  })

  parts <- do.call(rbind, strsplit(columns, ".", fixed = TRUE))
  out <- data.frame(
    metric = parts[, 1],
    threshold_kind = parts[, 2],
    lower = bounds[1, ],
    upper = bounds[2, ],
    boot_n = as.integer(bounds[3, ]),
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL
  out
}

#' An AUC that returns NA rather than erroring on a degenerate resample
#'
#' @param fn a `yardstick` `*_vec` function
#' @param truth the outcome factor
#' @param probability predicted probability of the event
#' @return the metric, or `NA_real_`
#' @keywords internal
safe_auc <- function(fn, truth, probability) {
  tryCatch(fn(truth, probability), error = function(e) NA_real_,
           warning = function(w) NA_real_)
}

#' Attach bootstrap bounds to the evaluation table
#'
#' Matched on the metric and on which cutoff it belongs to, rather than on row
#' order, so a metric appearing at both cutoffs gets the right pair each time.
#'
#' @param out the assembled evaluation table
#' @param bounds the result of [bootstrap_evaluation()]
#' @return `out` with `lower` and `upper` columns
#' @keywords internal
merge_bootstrap_bounds <- function(out, bounds) {
  out$lower <- NA_real_
  out$upper <- NA_real_
  if (is.null(bounds)) return(out)

  kind <- ifelse(is.na(out$threshold), "none",
                 ifelse(out$threshold == 0.5, "default", "optimal"))
  key <- paste(out$metric, kind, sep = "\r")
  reference <- paste(bounds$metric, bounds$threshold_kind, sep = "\r")

  at <- match(key, reference)
  out$lower <- bounds$lower[at]
  out$upper <- bounds$upper[at]
  out
}

#' The bootstrap interval on the classification cutoff
#'
#' Pulled out of the bounds table because it is not a metric and does not
#' belong in `evals.csv`, but it is the number to check before binarising a
#' projection: a cutoff that moves from 0.05 to 0.20 across resamples makes a
#' very different map at each end.
#'
#' @param bounds the result of [bootstrap_evaluation()]
#' @return `c(lower, upper)`, or `NULL` when the bootstrap did not run
#' @keywords internal
threshold_interval <- function(bounds) {
  if (is.null(bounds)) return(NULL)
  row <- bounds[bounds$metric == "classification_threshold", ]
  if (nrow(row) != 1 || is.na(row$lower)) return(NULL)
  c(lower = row$lower, upper = row$upper)
}

#' How many bootstrap resamples a run should draw
#'
#' `model.bootstrap` sets it. Zero or `false` turns the intervals off, which is
#' the escape hatch for a run where even a few seconds of resampling is not
#' wanted.
#'
#' @param config a config list, as returned by `load_config()`
#' @return an integer count, or `0L` when off
#' @keywords internal
bootstrap_times <- function(config) {
  spec <- config$model$bootstrap
  if (is.null(spec)) return(2000L)
  if (isFALSE(spec)) return(0L)
  if (isTRUE(spec)) return(2000L)

  times <- suppressWarnings(as.integer(spec))
  if (is.na(times) || times < 0) {
    stop("model.bootstrap must be a non-negative count, true, or false; got '",
         spec, "'.", call. = FALSE)
  }
  # One resample cannot produce an interval, and asking for a handful gives a
  # bound that moves every run. Refused rather than reported.
  if (times > 0 && times < 100) {
    stop("model.bootstrap must be 0 or at least 100; got ", times,
         ". A percentile interval from fewer resamples than that is noise.",
         call. = FALSE)
  }
  times
}
