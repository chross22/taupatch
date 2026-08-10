#' Is the gap between two model runs real?
#'
#' Two runs come back with two numbers — ROC AUC 0.857 against 0.871 — and
#' nothing in either says whether the gap is a difference between the models or
#' a difference between the stations the survey happened to visit. This answers
#' that, and answers the question that should be asked next when the gap is not
#' significant: **how large would a difference have had to be before this study
#' could have seen it?**
#'
#' Those two are reported together deliberately. "Not significant" on its own is
#' the least informative result in modelling — it conflates *these models
#' perform alike* with *this survey could not have told them apart*, and
#' `detectable` is what separates the two. A run that cannot detect anything
#' smaller than 0.09 in AUC has not shown that a 0.014 gap is absent.
#'
#' @section How the comparison is paired:
#' Every run cross-validates, so each carries a metric per fold rather than one
#' number, and two runs on the same stations can be compared fold by fold. That
#' pairing is most of the statistical power available: the folds vary a great
#' deal between themselves and much less between two models scored on the *same*
#' fold, and an unpaired comparison throws that away.
#'
#' Runs are matched on `.row`, the station index, not on position. Two runs with
#' different covariates drop different stations to missingness, so the
#' comparison is made on the stations both actually scored and the number
#' dropped is reported. A run that drops many is telling you something, which is
#' why this warns rather than silently intersecting.
#'
#' @section The test, and why it is not a plain t-test:
#' The per-fold differences go through [corrected_paired_test()], the same
#' Nadeau and Bengio (2003) correction the covariate jackknife uses, and for the
#' same reason: any two cross-validation training sets share most of their rows,
#' so folds are not independent and an uncorrected paired t-test finds
#' significance that is not there.
#'
#' Two-sided here, unlike the jackknife. Leaving a covariate out has a direction
#' worth testing against; asking which of two models is better does not.
#'
#' @section What "detectable" means:
#' The smallest true difference this comparison would have found significant at
#' `level`, with probability `power`, given the fold-to-fold variability it
#' actually saw:
#'
#' \deqn{d_{min} = SE \times (t_{1-\alpha/2, df} + t_{power, df})}
#'
#' It is a property of **this** design — this many folds, these stations, this
#' much variance between folds — not a general statement about the models. It
#' says nothing about whether a smaller difference exists, only that this study
#' would probably have missed it.
#'
#' @param runs a named list of two or more fitted runs, from
#'   [fit_patch_model()] or [fit_patch_ensemble()]. The first is the reference
#'   every other is compared against.
#' @param metric `"roc_auc"` or `"pr_auc"`; both are threshold-free, which is
#'   what lets them be compared fold by fold without a cutoff moving underneath
#' @param level confidence level for the interval and the test
#' @param power the power `detectable` is computed at
#' @return a data frame with one row per comparison against the reference:
#'   `reference`, `comparison`, `metric`, `reference_score`,
#'   `comparison_score`, `difference` (comparison minus reference), `lower`,
#'   `upper`, `statistic`, `df`, `p_value`, `detectable`, `n_folds`,
#'   `n_stations`, and `n_dropped`
#' @examples
#' \dontrun{
#' rf <- fit_patch_model(dat, within_config(config, type = "rf"))
#' gam <- fit_patch_model(dat, within_config(config, type = "gam"))
#'
#' compare_runs(list(rf = rf, gam = gam))
#' }
#' @references
#' Nadeau C, Bengio Y (2003). Inference for the generalization error. *Machine
#' Learning* **52**(3), 239-281. \doi{10.1023/A:1024068626366} — the variance
#' correction
#'
#' Dietterich TG (1998). Approximate statistical tests for comparing supervised
#' classification learning algorithms. *Neural Computation* **10**(7),
#' 1895-1923. \doi{10.1162/089976698300017197} — why comparing learning
#' algorithms on shared folds needs one
#'
#' Hoenig JM, Heisey DM (2001). The abuse of power: the pervasive fallacy of
#' power calculations for data analysis. *The American Statistician* **55**(1),
#' 19-24. \doi{10.1198/000313001300339897} — why `detectable` is reported
#' rather than the observed-power statistic it is often confused with
#' @seealso [power_curve()] for how the answer changes with more stations
#' @export
compare_runs <- function(runs, metric = "roc_auc", level = 0.95, power = 0.8) {
  if (!is.list(runs) || length(runs) < 2) {
    stop("compare_runs() needs a list of at least 2 fitted runs; got ",
         length(runs), ".", call. = FALSE)
  }
  if (is.null(names(runs)) || any(!nzchar(names(runs)))) {
    stop("Name the runs, so the comparison table can say which is which: ",
         "compare_runs(list(rf = rf_run, gam = gam_run)).", call. = FALSE)
  }
  if (!(metric %in% c("roc_auc", "pr_auc"))) {
    stop("compare_runs() metric must be 'roc_auc' or 'pr_auc', got '", metric,
         "'.\nBoth are threshold-free, which is what lets them be compared ",
         "fold by fold.", call. = FALSE)
  }

  predictions <- lapply(runs, run_predictions)
  reference <- names(runs)[1]

  rows <- lapply(names(runs)[-1], function(name) {
    compare_one(predictions[[reference]], predictions[[name]], reference, name,
                metric = metric, level = level, power = power)
  })

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' The held-out predictions a run kept, checked
#'
#' @param run a [fit_patch_model()] or [fit_patch_ensemble()] result
#' @return the predictions data frame
#' @keywords internal
run_predictions <- function(run) {
  predictions <- run$predictions
  needed <- c(".row", ".pred_patch", "patch", "id")
  missing <- setdiff(needed, names(predictions))
  if (is.null(predictions) || length(missing) > 0) {
    stop("A run has no usable held-out predictions (missing: ",
         paste(missing, collapse = ", "),
         ").\ncompare_runs() reads the cross-validated predictions each run ",
         "stores; a model fitted some other way cannot be compared this way.",
         call. = FALSE)
  }
  predictions
}

#' Compare one run against the reference
#'
#' @param reference_predictions held-out predictions of the reference run
#' @param other_predictions held-out predictions of the run being compared
#' @param reference the reference run's name
#' @param comparison the other run's name
#' @param metric `"roc_auc"` or `"pr_auc"`
#' @param level confidence level
#' @param power the power `detectable` is computed at
#' @return a one-row data frame
#' @keywords internal
compare_one <- function(reference_predictions, other_predictions, reference,
                        comparison, metric = "roc_auc", level = 0.95,
                        power = 0.8) {
  shared <- intersect(reference_predictions$.row, other_predictions$.row)
  dropped <- length(union(reference_predictions$.row,
                          other_predictions$.row)) - length(shared)
  if (length(shared) < 2) {
    stop("'", reference, "' and '", comparison, "' share ", length(shared),
         " stations, so there is nothing to compare.\nThey were probably ",
         "fitted on different data rather than on different models.",
         call. = FALSE)
  }
  if (dropped > 0) {
    warning("'", reference, "' and '", comparison, "' do not cover the same ",
            "stations: ", dropped, " of ", length(shared) + dropped,
            " are in one run and not the other, and the comparison uses the ",
            length(shared), " they share. Different covariates drop different ",
            "stations to missingness.", call. = FALSE)
  }

  a <- align_predictions(reference_predictions, shared)
  b <- align_predictions(other_predictions, shared)

  # Fold membership is the reference run's. Two runs seeded alike on identical
  # data fold identically, but a run that dropped rows folded differently, and
  # then only one of the two labellings can define the pairing.
  if (!identical(as.character(a$id), as.character(b$id))) {
    warning("'", reference, "' and '", comparison, "' assigned these stations ",
            "to different cross-validation folds, so the pairing uses '",
            reference, "'s. The comparison stays valid - both models are ",
            "scored on the same stations - but each fold is a held-out set ",
            "for one model and not necessarily for the other.", call. = FALSE)
  }

  folds <- split(seq_along(shared), a$id)
  score <- if (identical(metric, "pr_auc")) {
    yardstick::pr_auc_vec
  } else {
    yardstick::roc_auc_vec
  }
  scored <- function(truth, probability) {
    if (length(unique(truth)) < 2) return(NA_real_)
    tryCatch(score(truth, probability), error = function(e) NA_real_,
             warning = function(w) NA_real_)
  }

  per_fold <- vapply(folds, function(rows) {
    c(reference = scored(a$patch[rows], a$.pred_patch[rows]),
      comparison = scored(b$patch[rows], b$.pred_patch[rows]))
  }, numeric(2))

  differences <- per_fold["comparison", ] - per_fold["reference", ]
  test <- corrected_paired_test(differences, alternative = "two.sided")

  data.frame(
    reference = reference,
    comparison = comparison,
    metric = metric,
    reference_score = mean(per_fold["reference", ], na.rm = TRUE),
    comparison_score = mean(per_fold["comparison", ], na.rm = TRUE),
    difference = test$estimate,
    lower = test$estimate - critical_t(level, test$df) * test$std_err,
    upper = test$estimate + critical_t(level, test$df) * test$std_err,
    statistic = test$statistic,
    df = test$df,
    p_value = test$p_value,
    detectable = minimum_detectable(test$std_err, test$df, level, power),
    n_folds = test$n,
    n_stations = length(shared),
    n_dropped = dropped,
    stringsAsFactors = FALSE
  )
}

#' One run's predictions, restricted to shared stations and put in their order
#'
#' @param predictions a run's held-out predictions
#' @param shared the station indices to keep
#' @return the matching rows, in `shared` order
#' @keywords internal
align_predictions <- function(predictions, shared) {
  predictions[match(shared, predictions$.row), , drop = FALSE]
}

#' The two-sided critical value
#'
#' @param level confidence level
#' @param df degrees of freedom
#' @return the critical `t`, or `NA_real_`
#' @keywords internal
critical_t <- function(level, df) {
  if (is.na(df) || df < 1) return(NA_real_)
  stats::qt(1 - (1 - level) / 2, df = df)
}

#' The smallest difference a design could have detected
#'
#' Reported instead of "observed power", which is the statistic this is usually
#' confused with and which carries no information a p-value does not — it is a
#' deterministic function of it (Hoenig and Heisey 2001). The minimum detectable
#' difference is about the *design* rather than about the result, which is what
#' makes it worth reading beside a null finding.
#'
#' @param std_err the corrected standard error of the difference
#' @param df degrees of freedom
#' @param level confidence level
#' @param power the power to solve at
#' @return the smallest detectable difference, or `NA_real_`
#' @references
#' Hoenig JM, Heisey DM (2001). The abuse of power: the pervasive fallacy of
#' power calculations for data analysis. *The American Statistician* **55**(1),
#' 19-24. \doi{10.1198/000313001300339897}
#' @keywords internal
minimum_detectable <- function(std_err, df, level = 0.95, power = 0.8) {
  if (is.na(std_err) || is.na(df) || df < 1 || !is.finite(std_err)) {
    return(NA_real_)
  }
  std_err * (critical_t(level, df) + stats::qt(power, df = df))
}

#' The power a design has against a stated difference
#'
#' The complement of [minimum_detectable()]: given how variable the folds were,
#' how often would a true difference of `difference` be called significant?
#'
#' @param difference the true difference to detect
#' @param std_err the corrected standard error of the difference
#' @param df degrees of freedom
#' @param level confidence level
#' @return a probability, or `NA_real_`
#' @keywords internal
achieved_power <- function(difference, std_err, df, level = 0.95) {
  if (is.na(std_err) || is.na(df) || df < 1 || std_err <= 0) return(NA_real_)
  critical <- critical_t(level, df)
  ncp <- abs(difference) / std_err
  # Both tails, so a large difference in either direction counts as detected.
  stats::pt(-critical, df = df, ncp = ncp) +
    stats::pt(critical, df = df, ncp = ncp, lower.tail = FALSE)
}

#' How the comparison would improve with more stations
#'
#' [compare_runs()] answers what this survey could see. This answers what a
#' larger one would: it refits both runs on subsamples of the stations, at
#' several sizes, and traces how the power to detect a difference grows with
#' `n`.
#'
#' The curve is the useful artefact rather than any single number on it. Power
#' against sample size is steeply non-linear, and where a study sits on that
#' curve decides what the next survey is worth: a comparison at 0.35 power is
#' one more season away from being decisive, and one at 0.9 will not be improved
#' by more stations because it is already there.
#'
#' @section What it costs, and what it therefore skips:
#' `fractions × replicates × runs` cross-validations. Everything is refitted at
#' every size — the point is precisely that a model trained on half the stations
#' is a different model, not the same model evaluated on fewer — so this is the
#' expensive function in the package and parallelises over the whole grid.
#'
#' It goes through the same fold-scoring path the covariate jackknife uses,
#' which fits and scores and stops there. No bootstrap intervals, no variable
#' importance, no projection: none of it enters the curve, and all of it would
#' be paid for at every point.
#'
#' @section Subsampling stations, not folds:
#' Rows are drawn without replacement, and the folds are then built inside each
#' subsample. Reusing the full run's folds and thinning them would shrink the
#' held-out sets while leaving the training sets nearly whole, which measures
#' something else entirely — the curve has to come from models that were
#' actually trained on less.
#'
#' Both runs see the **same** subsample and the **same** folds at every point,
#' which is what keeps the comparison paired all the way down the curve.
#'
#' @section Reading it honestly:
#' The target difference defaults to the one observed on the full data, and that
#' is an estimate, not a truth. If the observed gap is itself mostly noise, the
#' curve answers "how many stations to reliably detect a difference this size"
#' for a size that may not be real. It is a projection under an assumption, and
#' the assumption is the observed effect.
#'
#' @param dat labeled modeling data from `label_patch()` with covariates attached
#' @param configs a named list of two or more configs to compare. The first is
#'   the reference; each is fitted exactly as its own run would be.
#' @param fractions the shares of the stations to fit at
#' @param replicates how many subsamples per fraction; the spread across them is
#'   what stops one unlucky draw from setting a point on the curve
#' @param difference the true difference to compute power against; `NULL` uses
#'   the one observed at the largest fraction
#' @param metric `"roc_auc"` or `"pr_auc"`
#' @param level confidence level the test would use
#' @param workers how many workers; see [resolve_workers()]
#' @param seed a seed, so a curve is reproducible
#' @return a data frame with one row per fraction: `fraction`, `n_stations`,
#'   `replicates`, `difference` (mean observed), `std_err`, `df`, `power`, and
#'   `detectable`. The target difference is on it as a `difference` attribute.
#' @examples
#' \dontrun{
#' rf <- config; rf$model$type <- "rf"
#' gam <- config; gam$model$type <- "gam"
#'
#' curve <- power_curve(dat, list(rf = rf, gam = gam))
#' curve[c("n_stations", "power", "detectable")]
#' }
#' @references
#' Nadeau C, Bengio Y (2003). Inference for the generalization error. *Machine
#' Learning* **52**(3), 239-281. \doi{10.1023/A:1024068626366}
#' @seealso [compare_runs()], which answers the same question for the data you
#'   already have
#' @export
power_curve <- function(dat, configs, fractions = c(0.25, 0.5, 0.75, 1),
                        replicates = 5, difference = NULL,
                        metric = "roc_auc", level = 0.95, workers = NULL,
                        seed = 42) {
  if (!is.list(configs) || length(configs) < 2) {
    stop("power_curve() needs at least 2 configs to compare; got ",
         length(configs), ".", call. = FALSE)
  }
  if (is.null(names(configs)) || any(!nzchar(names(configs)))) {
    stop("Name the configs, so the curve can say what it compared: ",
         "power_curve(dat, list(rf = rf_config, gam = gam_config)).",
         call. = FALSE)
  }
  fractions <- sort(unique(fractions[fractions > 0 & fractions <= 1]))
  if (length(fractions) == 0) {
    stop("fractions must be shares of the stations, in (0, 1].", call. = FALSE)
  }

  # Every run is scored on the rows every run can use, so a config whose
  # covariates are missing somewhere does not quietly get a different sample.
  predictors <- lapply(configs, function(config) predictor_names(dat, config))
  shared <- Reduce(union, predictors)
  model_data <- as.data.frame(dat[c(shared, "patch")])
  model_data <- model_data[stats::complete.cases(model_data), , drop = FALSE]
  if (nrow(model_data) < 10) {
    stop("Only ", nrow(model_data), " stations are complete across every ",
         "config's covariates, which is too few to build a power curve from.",
         call. = FALSE)
  }

  types <- vapply(configs, resolve_model_type, character(1))
  for (type in unique(types)) check_model_packages(type)

  tasks <- expand.grid(fraction = fractions, replicate = seq_len(replicates),
                       KEEP.OUT.ATTRS = FALSE)
  workers <- resolve_workers(workers, nrow(tasks))
  message("  power curve: ", nrow(tasks), " subsamples x ", length(configs),
          " runs across ", workers, if (workers == 1) " worker" else " workers")

  drawn <- taupatch_lapply(seq_len(nrow(tasks)), function(i) {
    power_point(model_data, configs, predictors, types,
                fraction = tasks$fraction[i], replicate = tasks$replicate[i],
                metric = metric, seed = seed)
  }, workers = workers, seed = seed)

  drawn <- do.call(rbind, Filter(Negate(is.null), drawn))
  if (is.null(drawn) || nrow(drawn) == 0) {
    stop("No subsample produced a usable comparison. The runs may be failing ",
         "to fit on a fraction of these stations.", call. = FALSE)
  }

  # The difference to have power against. Taken from the largest fraction,
  # which is the best estimate of it available.
  target <- difference %||% mean(
    drawn$difference[drawn$fraction == max(drawn$fraction)], na.rm = TRUE
  )

  out <- do.call(rbind, lapply(fractions, function(fraction) {
    at <- drawn[drawn$fraction == fraction, , drop = FALSE]
    usable <- at[is.finite(at$std_err) & is.finite(at$df), , drop = FALSE]
    if (nrow(usable) == 0) return(NULL)

    # Averaged across replicates rather than pooled: each replicate is its own
    # complete comparison, and averaging their standard errors is what keeps one
    # unlucky draw from setting the point.
    std_err <- mean(usable$std_err)
    df <- mean(usable$df)

    data.frame(
      fraction = fraction,
      n_stations = round(mean(usable$n_stations)),
      replicates = nrow(usable),
      difference = mean(usable$difference, na.rm = TRUE),
      std_err = std_err,
      df = df,
      power = achieved_power(target, std_err, df, level),
      detectable = minimum_detectable(std_err, df, level, power = 0.8),
      stringsAsFactors = FALSE
    )
  }))

  rownames(out) <- NULL
  attr(out, "difference") <- target
  out
}

#' One point on the power curve
#'
#' Draws a subsample, folds it, and scores every config on those same folds.
#'
#' @param model_data the complete-case modeling data
#' @param configs the configs being compared
#' @param predictors each config's predictors
#' @param types each config's model type
#' @param fraction the share of stations to draw
#' @param replicate which draw this is
#' @param metric `"roc_auc"` or `"pr_auc"`
#' @param seed the run's seed
#' @return a one-row data frame, or `NULL` when the draw could not be scored
#' @keywords internal
power_point <- function(model_data, configs, predictors, types, fraction,
                        replicate, metric = "roc_auc", seed = 42) {
  # Reproducible per point rather than per call, so a curve is the same however
  # its tasks were spread across workers.
  set.seed(seed + replicate * 1000L + round(fraction * 100))

  n <- max(10L, round(nrow(model_data) * fraction))
  if (n > nrow(model_data)) n <- nrow(model_data)
  drawn <- model_data[sample.int(nrow(model_data), n), , drop = FALSE]
  if (length(unique(drawn$patch)) < 2) return(NULL)

  folds <- tryCatch(
    rsample::vfold_cv(drawn, v = configs[[1]]$model$cv_folds %||% 10,
                      strata = "patch"),
    error = function(e) NULL
  )
  if (is.null(folds)) return(NULL)

  scores <- lapply(names(configs), function(name) {
    fold_scores(intersect(predictors[[name]], names(drawn)), folds,
                configs[[name]], types[[name]], metric)
  })
  names(scores) <- names(configs)

  reference <- scores[[1]]
  differences <- scores[[2]] - reference
  test <- corrected_paired_test(differences, alternative = "two.sided")

  data.frame(
    fraction = fraction, replicate = replicate, n_stations = n,
    difference = test$estimate, std_err = test$std_err, df = test$df,
    stringsAsFactors = FALSE
  )
}
