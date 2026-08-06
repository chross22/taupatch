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
    ggplot2::scale_fill_viridis_c(option = "magma", limits = c(0, 1),
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
  palette <- leaflet::colorNumeric("magma", domain = c(0, 1), na.color = "transparent")

  leaflet::leaflet() |>
    leaflet::addProviderTiles("CartoDB.Positron") |>
    leaflet::addRasterImage(rast, colors = palette, opacity = opacity) |>
    leaflet::fitBounds(extent[1], extent[3], extent[2], extent[4]) |>
    # leaflet stacks a continuous legend with the largest value at the bottom,
    # which reads backwards against the colour ramp beside it and against every
    # other scale in the package. Reversing the labels puts 0 at the bottom and
    # 1 at the top without touching the colours.
    leaflet::addLegend(
      pal = palette, values = c(0, 1), title = "P(patch)",
      labFormat = leaflet::labelFormat(
        transform = function(x) sort(x, decreasing = TRUE)
      )
    )
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
  subset <- covariate_subset(means, covariate)
  covariate <- subset$covariate[1]

  # Months as a reversed factor so January sits at the top, reading like a calendar.
  subset$month_label <- factor(month.abb[subset$month], levels = rev(month.abb))
  subset$year <- factor(subset$year)

  units <- covariate_units(covariate)
  legend_title <- if (nzchar(units)) paste0(covariate, "\n(", units, ")") else covariate

  p <- ggplot2::ggplot(subset, ggplot2::aes(x = .data$year, y = .data$month_label,
                                             fill = .data$mean)) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.4) +
    ggplot2::scale_fill_viridis_c(option = "magma", name = legend_title) +
    ggplot2::labs(title = covariate_label(covariate), x = NULL, y = NULL) +
    ggplot2::theme_minimal() +
    ggplot2::theme(panel.grid = ggplot2::element_blank(),
                   axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))

  if (is.null(path)) return(p)
  ggplot2::ggsave(path, plot = p, width = 8, height = 5, dpi = 150)
  invisible(path)
}

#' Plot a covariate's seasonal cycle, one line per year
#'
#' The same values the heatmap shows, read the other way: a heatmap is good at
#' where the record has gaps and poor at how large a departure is, because the
#' eye cannot compare two colours as precisely as two heights. A year running
#' warm shows here as a line sitting above the others.
#'
#' @param means a data frame from [covariate_monthly_means()]
#' @param covariate which covariate to plot; defaults to the first
#' @param path optional file to write the plot to instead of returning it
#' @return a `ggplot` object, or `path` invisibly when writing
#' @examples
#' \dontrun{
#' plot_covariate_seasonal(result$covariate_means, "SST")
#' }
#' @export
plot_covariate_seasonal <- function(means, covariate = NULL, path = NULL) {
  subset <- covariate_subset(means, covariate)
  covariate <- subset$covariate[1]
  subset$year <- factor(subset$year)

  p <- ggplot2::ggplot(subset, ggplot2::aes(x = .data$month, y = .data$mean,
                                             colour = .data$year,
                                             group = .data$year)) +
    ggplot2::geom_line(linewidth = 0.6) +
    ggplot2::geom_point(size = 1.2) +
    ggplot2::scale_x_continuous(breaks = sort(unique(subset$month)),
                                labels = month.abb[sort(unique(subset$month))]) +
    ggplot2::scale_colour_viridis_d(option = "viridis", name = NULL) +
    ggplot2::labs(title = covariate_label(covariate), x = NULL,
                  y = axis_label(covariate)) +
    ggplot2::theme_minimal()

  if (is.null(path)) return(p)
  ggplot2::ggsave(path, plot = p, width = 8, height = 4.5, dpi = 150)
  invisible(path)
}

#' Plot a covariate's annual mean over the record
#'
#' Collapses each year's months to one value, which is the view that shows drift
#' across the record rather than the seasonal cycle riding on top of it.
#'
#' The mean is taken over whichever months the run fetched. That makes the series
#' comparable between years only when every year covers the same months — which
#' is the normal case here, since covariates are fetched for a fixed month range,
#' but is worth knowing before reading a trend into it.
#'
#' @param means a data frame from [covariate_monthly_means()]
#' @param covariate which covariate to plot; defaults to the first
#' @param path optional file to write the plot to instead of returning it
#' @return a `ggplot` object, or `path` invisibly when writing
#' @examples
#' \dontrun{
#' plot_covariate_annual(result$covariate_means, "SST")
#' }
#' @export
plot_covariate_annual <- function(means, covariate = NULL, path = NULL) {
  subset <- covariate_subset(means, covariate)
  covariate <- subset$covariate[1]

  annual <- stats::aggregate(subset$mean, by = list(year = subset$year),
                              FUN = mean, na.rm = TRUE)
  names(annual)[2] <- "mean"

  p <- ggplot2::ggplot(annual, ggplot2::aes(x = .data$year, y = .data$mean)) +
    ggplot2::geom_line(linewidth = 0.6, colour = "#2c7fb8") +
    ggplot2::geom_point(size = 1.6, colour = "#2c7fb8") +
    ggplot2::labs(title = covariate_label(covariate), x = NULL,
                  y = axis_label(covariate)) +
    ggplot2::theme_minimal()

  if (is.null(path)) return(p)
  ggplot2::ggsave(path, plot = p, width = 8, height = 3.5, dpi = 150)
  invisible(path)
}

#' One covariate's rows from a monthly-means table
#'
#' @param means a data frame from [covariate_monthly_means()]
#' @param covariate a covariate name, or `NULL` for the first
#' @return the matching rows; errors listing what is available if there are none
#' @keywords internal
covariate_subset <- function(means, covariate = NULL) {
  covariate <- covariate %||% means$covariate[1]
  subset <- means[means$covariate == covariate, ]
  if (nrow(subset) == 0) {
    stop("No values for covariate '", covariate, "'. Available: ",
         paste(unique(means$covariate), collapse = ", "), call. = FALSE)
  }
  subset
}

#' Axis label for a covariate, with units where the catalog has them
#'
#' @param covariate a covariate name
#' @return a label string
#' @keywords internal
axis_label <- function(covariate) {
  units <- covariate_units(covariate)
  if (nzchar(units)) paste0(covariate, " (", units, ")") else covariate
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

#' Map the stations, coloured by abundance
#'
#' Where the survey actually went, and where the animals were. Worth looking at
#' before fitting anything: a study area drawn wider than the stations, a year
#' that sampled only half the shelf, or an abundance field that is all zeros
#' outside one corner are all visible here and invisible in a metrics table.
#'
#' @param dat station data from [load_zoop_data()]
#' @param transform how to scale the colour; abundance spans orders of magnitude,
#'   so the default is log1p
#' @param path optional file to write the plot to instead of returning it
#' @return a `ggplot` object, or `path` invisibly when writing
#' @examples
#' \dontrun{
#' plot_station_map(load_zoop_data(config))
#' }
#' @export
plot_station_map <- function(dat, transform = c("log1p", "none"), path = NULL) {
  transform <- match.arg(transform)
  dat <- dat[!is.na(dat$lon) & !is.na(dat$lat), ]
  if (nrow(dat) == 0) stop("No stations with coordinates to map.", call. = FALSE)

  dat$value <- if (transform == "log1p") log1p(dat$abundance) else dat$abundance
  legend <- if (transform == "log1p") "log(1 + abundance)" else "Abundance"

  p <- ggplot2::ggplot(dat, ggplot2::aes(x = .data$lon, y = .data$lat,
                                          colour = .data$value)) +
    coastline_layer(dat) +
    ggplot2::geom_point(size = 1.4, alpha = 0.8) +
    ggplot2::scale_colour_viridis_c(option = "magma", name = legend) +
    # coord_sf() rather than coord_quickmap(): geom_sf() refuses to draw under
    # anything else, and the refusal comes at draw time rather than when the
    # plot is built, so it survives a ggplot_build() check and fails in the
    # app. Both give a sensible aspect for lon/lat; only one of them coexists
    # with a coastline.
    ggplot2::coord_sf(xlim = range(dat$lon), ylim = range(dat$lat),
                      default_crs = 4326) +
    ggplot2::labs(x = NULL, y = NULL) +
    ggplot2::theme_minimal()

  if (is.null(path)) return(p)
  ggplot2::ggsave(path, plot = p, width = 7, height = 6, dpi = 150)
  invisible(path)
}

#' Abundance over the record
#'
#' One point per station against its own year and month, with the monthly median
#' over the top. The seasonal cycle, the swings between years, and the months
#' nobody sampled all read from the same picture.
#'
#' @param dat station data from [load_zoop_data()]

#' @param path optional file to write the plot to instead of returning it
#' @return a `ggplot` object, or `path` invisibly when writing
#' @examples
#' \dontrun{
#' plot_station_series(load_zoop_data(config))
#' }
#' @export
plot_station_series <- function(dat, path = NULL) {
  dat <- dat[!is.na(dat$abundance), ]
  if (nrow(dat) == 0) stop("No abundances to plot.", call. = FALSE)

  # Each station at its own month on a continuous axis, so the seasonal cycle
  # and the drift between years are one picture rather than two.
  dat$x <- dat$year + (dat$month - 0.5) / 12
  monthly <- stats::aggregate(dat$abundance, by = list(x = dat$x),
                              FUN = stats::median, na.rm = TRUE)
  names(monthly)[2] <- "median"

  p <- ggplot2::ggplot(dat, ggplot2::aes(x = .data$x, y = .data$abundance)) +
    ggplot2::geom_jitter(width = 0.02, alpha = 0.25, size = 1,
                         colour = "#2c7fb8") +
    # The monthly median as points, not a line. A survey does not sample every
    # month, and a line drawn across a gap asserts a trajectory through months
    # nobody went to sea in.
    ggplot2::geom_point(data = monthly, ggplot2::aes(y = .data$median),
                        size = 1.9, colour = "#08306b") +
    # Abundance is heavily right-skewed, so a linear axis is one cloud at the
    # bottom and a handful of points far above it.
    ggplot2::scale_y_continuous(trans = "log1p") +
    ggplot2::labs(x = NULL, y = "Abundance (log scale)") +
    ggplot2::theme_minimal()

  if (is.null(path)) return(p)
  ggplot2::ggsave(path, plot = p, width = 8, height = 4, dpi = 150)
  invisible(path)
}

#' Summary of a station dataset
#'
#' The numbers worth knowing before fitting: how many stations, over what period
#' and area, and how the abundances are distributed. The proportion of zeros is
#' the one that most often explains a disappointing model.
#'
#' @param dat station data from [load_zoop_data()]
#' @return a data frame of `quantity` and `value`
#' @examples
#' \dontrun{
#' station_summary(load_zoop_data(config))
#' }
#' @export
station_summary <- function(dat) {
  abundance <- dat$abundance[!is.na(dat$abundance)]
  quantiles <- stats::quantile(abundance, c(0.5, 0.9, 1), na.rm = TRUE,
                                names = FALSE)

  data.frame(
    quantity = c("Stations", "Years", "Months sampled", "Longitude", "Latitude",
                 "Median abundance", "90th percentile", "Maximum",
                 "Zero or absent"),
    value = c(
      format(nrow(dat), big.mark = ","),
      paste(range(dat$year, na.rm = TRUE), collapse = " to "),
      paste(sort(unique(dat$month)), collapse = ", "),
      paste(round(range(dat$lon, na.rm = TRUE), 2), collapse = " to "),
      paste(round(range(dat$lat, na.rm = TRUE), 2), collapse = " to "),
      signif(quantiles[1], 4), signif(quantiles[2], 4), signif(quantiles[3], 4),
      paste0(round(100 * mean(abundance == 0), 1), "%")
    ),
    stringsAsFactors = FALSE
  )
}

#' A coastline under a station map
#'
#' Points on an empty background say where stations are relative to each other
#' and nothing about where they are. A coastline is the difference between a
#' scatter plot and a map.
#'
#' `rnaturalearth` is a Suggests, so a map without it is the scatter plot: worth
#' less, but not worth failing over.
#'
#' @param dat station data, used to size the extent fetched
#' @param margin degrees of coast to include beyond the stations
#' @return a `ggplot2` layer, or `NULL` when the coastline is unavailable
#' @keywords internal
coastline_layer <- function(dat, margin = 2) {
  if (!requireNamespace("rnaturalearth", quietly = TRUE)) return(NULL)

  land <- tryCatch(
    rnaturalearth::ne_countries(scale = "medium", returnclass = "sf"),
    error = function(e) NULL
  )
  if (is.null(land)) return(NULL)

  # Cropped to the stations, since drawing the whole world and then zooming
  # leaves ggplot rendering geometry it will not show.
  box <- c(xmin = min(dat$lon) - margin, xmax = max(dat$lon) + margin,
           ymin = min(dat$lat) - margin, ymax = max(dat$lat) + margin)
  # The crop warns that attributes are assumed constant across geometries,
  # which is true and irrelevant: nothing here reads an attribute.
  land <- tryCatch(suppressWarnings(sf::st_crop(sf::st_make_valid(land), box)),
                   error = function(e) land)

  ggplot2::geom_sf(data = land, inherit.aes = FALSE, fill = "grey92",
                   colour = "grey70", linewidth = 0.25)
}
