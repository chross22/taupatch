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
