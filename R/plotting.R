#' Plot a monthly habitat suitability projection
#'
#' @param predicted a projection from `predict_grid()`, with `lon`/`lat`/`suitability`
#' @param year year being projected
#' @param month month being projected
#' @param species species name, for the title
#' @param path where to write the PNG
#' @return `path`, invisibly
#' @export
plot_projection <- function(predicted, year, month, species, path) {
  p <- ggplot2::ggplot(predicted, ggplot2::aes(x = .data$lon, y = .data$lat,
                                                fill = .data$suitability)) +
    ggplot2::geom_raster() +
    ggplot2::scale_fill_viridis_c(option = "inferno", limits = c(0, 1),
                                   na.value = "white", name = "P(patch)") +
    ggplot2::coord_quickmap() +
    ggplot2::labs(title = paste0(species, " - ", month.name[month], " ", year),
                  x = NULL, y = NULL) +
    ggplot2::theme_bw() +
    ggplot2::theme(panel.grid = ggplot2::element_blank())

  ggplot2::ggsave(path, plot = p, width = 7, height = 7, dpi = 150)
  invisible(path)
}

#' Build a leaflet map of a projection GeoTIFF
#'
#' @param geotiff path to a projection GeoTIFF written by `project_patch_model()`
#' @param opacity overlay opacity
#' @return a `leaflet` map widget
#' @examples
#' \dontrun{
#' result <- run_taupatch("inst/configs/mock_test.yaml")
#' projection_map(result$projections$geotiff[1])
#' }
#' @export
projection_map <- function(geotiff, opacity = 0.8) {
  if (!requireNamespace("leaflet", quietly = TRUE)) {
    stop("The 'leaflet' package is required. Install it with install.packages('leaflet').",
         call. = FALSE)
  }
  rast <- terra::rast(geotiff)

  # unname(): terra's SpatExtent indexing returns *named* numerics ("xmin"), and
  # jsonlite serializes a named vector as a JSON object rather than a scalar.
  # fitBounds would then receive {"xmin": -70.1} instead of -70.1 and silently
  # fail to set a view - leaving leaflet with no center or zoom, so it requests
  # no tiles and positions no overlay, and the map renders as a blank grey box.
  extent <- unname(as.vector(terra::ext(rast)))  # xmin, xmax, ymin, ymax
  palette <- leaflet::colorNumeric("inferno", domain = c(0, 1), na.color = "transparent")

  leaflet::leaflet() |>
    leaflet::addProviderTiles("CartoDB.Positron") |>
    leaflet::addRasterImage(rast, colors = palette, opacity = opacity) |>
    leaflet::fitBounds(extent[1], extent[3], extent[2], extent[4]) |>
    leaflet::addLegend(pal = palette, values = c(0, 1), title = "P(patch)")
}

#' Plot a month-by-year heatmap of a covariate
#'
#' Shows the study-area mean of one covariate for every month and year, which
#' makes the seasonal cycle read down each column and interannual change read
#' across rows. Useful for spotting gaps in the covariate record and for sanity-
#' checking that a fetched variable behaves the way it should (SST peaking in
#' late summer, for instance).
#'
#' @param means a data frame from `covariate_monthly_means()`
#' @param covariate which covariate to plot; defaults to the first present
#' @param path where to write a PNG; `NULL` returns the plot instead
#' @return the plot object, or `path` invisibly when written to disk
#' @examples
#' \dontrun{
#' result <- run_taupatch("inst/configs/mock_test.yaml")
#' plot_covariate_heatmap(result$covariate_means, "SST")
#' }
#' @export
plot_covariate_heatmap <- function(means, covariate = NULL, path = NULL) {
  covariate <- covariate %||% means$covariate[1]
  subset <- means[means$covariate == covariate, ]
  if (nrow(subset) == 0) {
    stop("No values for covariate '", covariate, "'. Available: ",
         paste(unique(means$covariate), collapse = ", "), call. = FALSE)
  }

  # Months as a reversed factor so January sits at the top, reading like a calendar.
  subset$month_label <- factor(month.abb[subset$month], levels = rev(month.abb))
  subset$year <- factor(subset$year)

  units <- covariate_units(covariate)
  legend_title <- if (nzchar(units)) paste0(covariate, "\n(", units, ")") else covariate

  p <- ggplot2::ggplot(subset, ggplot2::aes(x = .data$year, y = .data$month_label,
                                             fill = .data$mean)) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.4) +
    ggplot2::scale_fill_viridis_c(option = "viridis", name = legend_title) +
    ggplot2::labs(title = covariate_label(covariate), x = NULL, y = NULL) +
    ggplot2::theme_minimal() +
    ggplot2::theme(panel.grid = ggplot2::element_blank(),
                   axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))

  if (is.null(path)) return(p)
  ggplot2::ggsave(path, plot = p, width = 8, height = 5, dpi = 150)
  invisible(path)
}

#' Units for a covariate name
#'
#' @param covariate a covariate name
#' @return the units string, or `""` for covariates not in the catalog
#' @keywords internal
covariate_units <- function(covariate) {
  info <- covariate_info(include_derived = TRUE)
  match <- info$units[info$name == covariate]
  if (length(match) == 0) "" else match[1]
}

#' Long name for a covariate, falling back to the name itself
#'
#' @param covariate a covariate name
#' @return a display label
#' @keywords internal
covariate_label <- function(covariate) {
  info <- covariate_info(include_derived = TRUE)
  match <- info$label[info$name == covariate]
  if (length(match) == 0) covariate else paste0(covariate, " - ", match[1])
}

#' Plot cross-validated ROC curves
#'
#' Draws one curve per resampling fold plus the pooled curve across all of them.
#'
#' Per-fold curves are shown rather than only the pooled one because they carry
#' information the summary AUC hides: a model whose folds agree closely is a
#' different proposition from one averaging the same AUC out of wildly varying
#' folds, and the second is not trustworthy at a single station even though both
#' report the same number.
#'
#' The curves come from held-out predictions, so they describe performance on
#' data the model did not see. A curve drawn on training data would sit much
#' closer to the corner and mean nothing.
#'
#' @param predictions the `predictions` element of a `fit_patch_model()` result
#' @param path where to write a PNG; `NULL` returns the plot instead
#' @return the plot object, or `path` invisibly when written to disk
#' @examples
#' \dontrun{
#' result <- run_taupatch("inst/configs/mock_test.yaml")
#' plot_roc_curve(result$model$predictions)
#' }
#' @export
plot_roc_curve <- function(predictions, path = NULL) {
  check_predictions(predictions)

  per_fold <- NULL
  if ("id" %in% names(predictions)) {
    per_fold <- do.call(rbind, lapply(split(predictions, predictions$id), function(fold) {
      curve <- yardstick::roc_curve(fold, truth = "patch", ".pred_patch")
      curve$fold <- fold$id[1]
      curve
    }))
  }

  pooled <- yardstick::roc_curve(predictions, truth = "patch", ".pred_patch")
  auc <- yardstick::roc_auc(predictions, truth = "patch", ".pred_patch")$.estimate

  p <- ggplot2::ggplot()
  if (!is.null(per_fold)) {
    p <- p + ggplot2::geom_path(
      data = per_fold,
      ggplot2::aes(x = 1 - .data$specificity, y = .data$sensitivity,
                   group = .data$fold),
      colour = "grey70", linewidth = 0.4, alpha = 0.8
    )
  }

  p <- p +
    # The diagonal is what a coin flip achieves; distance above it is the signal.
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dashed",
                         colour = "grey40") +
    ggplot2::geom_path(
      data = pooled,
      ggplot2::aes(x = 1 - .data$specificity, y = .data$sensitivity),
      colour = "#2c7fb8", linewidth = 1
    ) +
    ggplot2::annotate("text", x = 0.97, y = 0.03, hjust = 1, vjust = 0,
                      label = paste0("AUC = ", format(round(auc, 3), nsmall = 3))) +
    ggplot2::coord_equal(xlim = c(0, 1), ylim = c(0, 1)) +
    ggplot2::labs(
      title = "Cross-validated ROC",
      subtitle = if (!is.null(per_fold)) "Grey: individual folds. Blue: pooled." else NULL,
      x = "False positive rate (1 - specificity)",
      y = "True positive rate (sensitivity)"
    ) +
    ggplot2::theme_minimal()

  write_or_return(p, path, width = 6, height = 6)
}

#' Plot the precision-recall curve
#'
#' More informative than ROC when the classes are imbalanced, which they are here
#' by construction: a 90th-percentile threshold makes only 10% of stations
#' patches. ROC uses the false positive rate, whose denominator is the large
#' non-patch class, so a model can look excellent while most of its positive
#' predictions are still wrong. Precision asks the question that actually matters
#' for a patch map — of the places called patch, how many are?
#'
#' The baseline is the patch prevalence: what precision random guessing achieves.
#'
#' @param predictions the `predictions` element of a `fit_patch_model()` result
#' @param path where to write a PNG; `NULL` returns the plot instead
#' @return the plot object, or `path` invisibly when written to disk
#' @export
plot_pr_curve <- function(predictions, path = NULL) {
  check_predictions(predictions)

  curve <- yardstick::pr_curve(predictions, truth = "patch", ".pred_patch")
  auc <- yardstick::pr_auc(predictions, truth = "patch", ".pred_patch")$.estimate
  prevalence <- mean(predictions$patch == "patch")

  p <- ggplot2::ggplot(curve, ggplot2::aes(x = .data$recall, y = .data$precision)) +
    ggplot2::geom_hline(yintercept = prevalence, linetype = "dashed",
                        colour = "grey40") +
    ggplot2::geom_path(colour = "#2c7fb8", linewidth = 1) +
    ggplot2::annotate("text", x = 0.97, y = prevalence, hjust = 1, vjust = -0.5,
                      label = paste0("prevalence = ", format(round(prevalence, 3), nsmall = 3)),
                      colour = "grey30", size = 3) +
    ggplot2::coord_equal(xlim = c(0, 1), ylim = c(0, 1)) +
    ggplot2::labs(
      title = "Cross-validated precision-recall",
      subtitle = paste0("PR AUC = ", format(round(auc, 3), nsmall = 3),
                        ". Dashed line is chance at this prevalence."),
      x = "Recall (of real patches, how many were found)",
      y = "Precision (of predicted patches, how many were real)"
    ) +
    ggplot2::theme_minimal()

  write_or_return(p, path, width = 6, height = 6)
}

#' Plot probability calibration
#'
#' Whether predicted probabilities mean what they say: of the cells given a 0.7
#' chance of being a patch, are about 70% patches?
#'
#' This matters for a suitability map specifically. The maps are read as
#' probabilities and compared between months and regions, but a model can rank
#' cells perfectly — a high AUC — while its probabilities are systematically too
#' confident or too timid. Ranking is all AUC measures; calibration is what makes
#' the number on the map mean something.
#'
#' Random forests are commonly under-confident at the extremes, since a
#' probability is a vote share across trees and unanimity is rare.
#'
#' @param predictions the `predictions` element of a `fit_patch_model()` result
#' @param bins number of probability bins
#' @param path where to write a PNG; `NULL` returns the plot instead
#' @return the plot object, or `path` invisibly when written to disk
#' @export
plot_calibration <- function(predictions, bins = 10, path = NULL) {
  check_predictions(predictions)

  edges <- seq(0, 1, length.out = bins + 1)
  bin <- cut(predictions$.pred_patch, breaks = edges, include.lowest = TRUE)

  summary <- data.frame(
    predicted = tapply(predictions$.pred_patch, bin, mean),
    observed = tapply(predictions$patch == "patch", bin, mean),
    n = as.numeric(table(bin))
  )
  summary <- summary[summary$n > 0, ]

  p <- ggplot2::ggplot(summary, ggplot2::aes(x = .data$predicted, y = .data$observed)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dashed",
                         colour = "grey40") +
    ggplot2::geom_line(colour = "#2c7fb8") +
    # Point size shows how many cells back each bin: the extremes are usually
    # sparse, and a wild-looking point there may rest on a handful of stations.
    ggplot2::geom_point(ggplot2::aes(size = .data$n), colour = "#2c7fb8") +
    ggplot2::scale_size_continuous(name = "stations", range = c(1, 6)) +
    ggplot2::coord_equal(xlim = c(0, 1), ylim = c(0, 1)) +
    ggplot2::labs(
      title = "Probability calibration",
      subtitle = "On the dashed line, a predicted probability means what it says.",
      x = "Mean predicted probability", y = "Observed patch fraction"
    ) +
    ggplot2::theme_minimal()

  write_or_return(p, path, width = 6.5, height = 6)
}

#' Plot performance across classification thresholds
#'
#' Sensitivity, specificity, and TSS as the probability cutoff moves from 0 to 1,
#' with the TSS-maximising cutoff marked.
#'
#' The metrics table reports sensitivity and specificity at the default 0.5 cut,
#' which is rarely the right one for imbalanced data — the original pipeline
#' binarised its projections at a ROC-derived cutoff for exactly this reason. This
#' shows what the trade-off looks like across the whole range, and where it is
#' best balanced.
#'
#' @param predictions the `predictions` element of a `fit_patch_model()` result
#' @param path where to write a PNG; `NULL` returns the plot instead
#' @return the plot object, or `path` invisibly when written to disk
#' @export
plot_threshold_performance <- function(predictions, path = NULL) {
  check_predictions(predictions)

  curve <- yardstick::roc_curve(predictions, truth = "patch", ".pred_patch")
  # roc_curve() pads the ends with infinite thresholds, which cannot be plotted.
  curve <- curve[is.finite(curve$.threshold), ]
  curve$tss <- curve$sensitivity + curve$specificity - 1
  best <- curve[which.max(curve$tss), ]

  long <- rbind(
    data.frame(threshold = curve$.threshold, value = curve$sensitivity,
               metric = "sensitivity"),
    data.frame(threshold = curve$.threshold, value = curve$specificity,
               metric = "specificity"),
    data.frame(threshold = curve$.threshold, value = curve$tss, metric = "TSS")
  )

  p <- ggplot2::ggplot(long, ggplot2::aes(x = .data$threshold, y = .data$value,
                                          colour = .data$metric)) +
    ggplot2::geom_vline(xintercept = best$.threshold, linetype = "dashed",
                        colour = "grey40") +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::scale_colour_manual(values = c(sensitivity = "#2c7fb8",
                                            specificity = "#d95f02",
                                            TSS = "#1b9e77"), name = NULL) +
    ggplot2::labs(
      title = "Performance across classification thresholds",
      subtitle = paste0("TSS peaks at ", format(round(best$.threshold, 3), nsmall = 3),
                        " (TSS = ", format(round(best$tss, 3), nsmall = 3),
                        "), not necessarily at 0.5."),
      x = "Probability cutoff for calling a cell a patch", y = NULL
    ) +
    ggplot2::theme_minimal()

  write_or_return(p, path, width = 7, height = 5)
}

#' Check that a predictions table can be plotted
#'
#' @param predictions the `predictions` element of a `fit_patch_model()` result
#' @return `TRUE` invisibly; errors otherwise
#' @keywords internal
check_predictions <- function(predictions) {
  if (is.null(predictions) || nrow(predictions) == 0) {
    stop("No held-out predictions to plot. Refit the model, which retains them.",
         call. = FALSE)
  }
  if (!".pred_patch" %in% names(predictions)) {
    stop("Expected a '.pred_patch' column in the predictions.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Write a plot to disk or return it
#'
#' @param plot a ggplot object
#' @param path where to write, or `NULL` to return the plot
#' @param width,height PNG dimensions in inches
#' @return the plot, or `path` invisibly
#' @keywords internal
write_or_return <- function(plot, path, width = 7, height = 5) {
  if (is.null(path)) return(plot)
  ggplot2::ggsave(path, plot = plot, width = width, height = height, dpi = 150)
  invisible(path)
}

#' Plot variable importance
#'
#' @param importance an importance tibble from `fit_patch_model()`
#' @param path where to write the PNG; `NULL` returns the plot instead
#' @return the plot object, or `path` invisibly when written to disk
#' @export
plot_importance <- function(importance, path = NULL) {
  p <- ggplot2::ggplot(
    importance,
    ggplot2::aes(x = stats::reorder(.data$variable, .data$importance),
                 y = .data$importance)
  ) +
    ggplot2::geom_col(fill = "steelblue") +
    ggplot2::coord_flip() +
    ggplot2::labs(x = NULL, y = "Permutation importance") +
    ggplot2::theme_bw()

  if (is.null(path)) return(p)
  ggplot2::ggsave(path, plot = p, width = 6, height = 4, dpi = 150)
  invisible(path)
}
