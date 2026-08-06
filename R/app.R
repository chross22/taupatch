#' Launch the taupatch Shiny app
#'
#' Opens a GUI for selecting a species, threshold, extent, and model settings,
#' running the pipeline, and browsing the resulting monthly suitability maps.
#'
#' The app runs the same `run_taupatch()` pipeline as a scripted run — the config
#' it builds from the form is shown on its Config tab, so a run driven from the
#' GUI can be reproduced from a config file.
#'
#' @param config_path path to a config YAML used as the app's starting state;
#'   defaults to the shipped mock config, which runs without network access
#' @param max_upload_mb largest zooplankton CSV the app will accept as an
#'   upload, in megabytes
#' @param output_dir where runs launched from the app write their output;
#'   defaults to a session temporary directory
#' @param ... passed to `shiny::runApp()`
#' @return the value of `shiny::runApp()`, invisibly
#' @examples
#' \dontrun{
#' # Try the interface on synthetic data, no Copernicus credentials needed
#' run_taupatch_app()
#'
#' # Start from a real config
#' run_taupatch_app("inst/configs/ctyp_gom.yaml")
#' }
#' @export
run_taupatch_app <- function(config_path = NULL, output_dir = NULL,
                             max_upload_mb = 200, ...) {
  for (pkg in c("shiny", "leaflet")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("The '", pkg, "' package is required to run the app. ",
           "Install it with install.packages('", pkg, "').", call. = FALSE)
    }
  }

  config_path <- config_path %||% system.file("configs", "mock_test.yaml",
                                               package = "taupatch")
  if (!nzchar(config_path) || !file.exists(config_path)) {
    stop("Config file not found: ", config_path, call. = FALSE)
  }
  config <- load_config(config_path)

  # The shipped mock config lives inside the installed package, so its relative
  # paths would otherwise resolve into the installation directory.
  if (is.null(output_dir)) {
    output_dir <- file.path(tempdir(), "taupatch_app")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  config$paths$output_dir <- output_dir
  if (config$covariates$source == "mock") {
    config$paths$zoop_file <- file.path(output_dir, "mock_zooplankton.csv")
    # Written up front rather than on the first run, so the app's life-stage
    # picker - which reads the available stages out of the database - is
    # populated as soon as the page loads.
    if (!file.exists(config$paths$zoop_file)) {
      generate_mock_zoop_data(config)
    }
  }

  app_dir <- system.file("shiny", package = "taupatch")
  if (!nzchar(app_dir)) {
    stop("Could not locate the app directory in the installed package.", call. = FALSE)
  }

  # Shiny caps uploads at 5 MB by default, which the zooplankton database is
  # comfortably over. Raised so the app's file picker is actually usable, and a
  # parameter rather than a constant since the ceiling is really about the
  # machine the app is running on.
  withr_options <- options(taupatch.app_config = config,
                           shiny.maxRequestSize = max_upload_mb * 1024^2)
  on.exit(options(withr_options), add = TRUE)

  invisible(shiny::runApp(app_dir, ...))
}
