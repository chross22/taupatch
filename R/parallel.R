#' Map a function over a list, in parallel where that is possible
#'
#' The one place in the package that spawns workers. Both callers — the
#' covariate jackknife and the multi-algorithm ensemble — are the same shape:
#' a few dozen independent model fits, each expensive enough that the cost of
#' handing it to another core disappears, and none of them talking to each
#' other.
#'
#' @section Forks, not sockets:
#' `parallel::mclapply()` forks, so each worker starts with the fitted
#' recipe, the folds and the station table already in memory and copy-on-write
#' keeps that free. A PSOCK cluster would have to serialize all of it to every
#' worker for every task, which on a station table is most of the time the
#' parallelism was meant to save.
#'
#' The cost is that forking does not exist on Windows, where this falls back to
#' running sequentially and says so rather than pretending. A jackknife is still
#' perfectly usable there — it is one model fit per covariate per fold, which is
#' minutes, not hours — it just does not get faster with more cores.
#'
#' @section Reproducibility:
#' Forked workers inherit the parent's RNG state, so without help every one of
#' them would draw the same random numbers — which for a random forest means the
#' members are correlated in a way nothing downstream can see. `L'Ecuyer-CMRG`
#' gives each worker an independent, reproducible substream, and the previous
#' RNG kind and seed are both restored on the way out so a run's own seed still
#' governs everything after this.
#'
#' @param x a list or vector to map over
#' @param fun the function to apply
#' @param workers how many workers; `1` runs sequentially
#' @param seed optional seed, so the mapping is reproducible
#' @return a list, as `lapply()`
#' @keywords internal
taupatch_lapply <- function(x, fun, workers = 1L, seed = NULL) {
  workers <- min(as.integer(workers), length(x))

  if (!is.null(seed)) {
    if (exists(".Random.seed", envir = globalenv())) {
      state <- get(".Random.seed", envir = globalenv())
      on.exit(assign(".Random.seed", state, envir = globalenv()), add = TRUE)
    }
  }

  if (is.na(workers) || workers <= 1L) {
    if (!is.null(seed)) set.seed(seed)
    return(lapply(x, fun))
  }

  previous_kind <- RNGkind("L'Ecuyer-CMRG")[1]
  on.exit(RNGkind(previous_kind), add = TRUE)
  if (!is.null(seed)) set.seed(seed)

  # mc.preschedule = FALSE deals out one task at a time. The tasks here are
  # deliberately uneven - a model on one covariate costs a fraction of a model
  # on all of them - and prescheduling would hand every cheap task to one core
  # and leave it idle while another works through the expensive ones.
  out <- parallel::mclapply(x, fun, mc.cores = workers, mc.preschedule = FALSE)

  failed <- vapply(out, inherits, logical(1), "try-error")
  if (any(failed)) {
    stop("A parallel worker failed: ",
         conditionMessage(attr(out[[which(failed)[1]]], "condition")),
         call. = FALSE)
  }
  out
}

#' How many workers to run with
#'
#' `NULL` or `true` means "as many as this machine can spare", which is one
#' fewer than its physical cores — leaving one is what keeps the session it was
#' launched from responsive. `false` or `1` is sequential.
#'
#' Capped at `n`, since a task list of six cannot use twelve workers, and forced
#' to 1 on Windows, where [taupatch_lapply()] cannot fork.
#'
#' @param workers the configured value: `NULL`, a logical, or a count
#' @param n how many tasks there are to spread
#' @param quiet whether to suppress the Windows fallback message
#' @return an integer worker count, at least 1
#' @keywords internal
resolve_workers <- function(workers = NULL, n = 1L, quiet = FALSE) {
  requested <- if (is.null(workers) || isTRUE(workers)) {
    available <- suppressWarnings(parallel::detectCores(logical = FALSE))
    if (is.na(available)) 1L else max(1L, available - 1L)
  } else if (isFALSE(workers)) {
    1L
  } else {
    count <- suppressWarnings(as.integer(workers))
    if (is.na(count) || count < 1) {
      stop("workers must be a positive count, true, or false; got '",
           paste(workers, collapse = ", "), "'.", call. = FALSE)
    }
    count
  }

  if (requested > 1L && identical(.Platform$OS.type, "windows")) {
    if (!quiet) {
      message("  parallel fits need forking, which Windows does not have; ",
              "running sequentially")
    }
    return(1L)
  }
  max(1L, min(requested, as.integer(n)))
}
