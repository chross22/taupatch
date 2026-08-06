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
run_taupatch_app <- function(config_path = NULL, output_dir = NULL, ...) {
  # shinyFiles is required rather than optional. As a Suggests it produced the
  # worst failure available: the Browse button was simply absent, with nothing
  # on screen to say why, on any machine whose library happened not to have it.
  for (pkg in c("shiny", "leaflet", "shinyFiles")) {
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

  # Resolved once, here, and passed on as an absolute path. Leaving it to PATH
  # works from a terminal and fails from a GUI, and fails again in every
  # parallel worker even when it worked in the session that spawned them.
  client <- copernicus_client()
  withr_options <- options(
    taupatch.app_config = config,
    datamatch.copernicusmarine = if (nzchar(client)) client else
      getOption("datamatch.copernicusmarine")
  )
  if (nzchar(client)) {
    message("Copernicus Marine client: ", client)
  } else {
    message("Copernicus Marine client not found. Runs using covariates.source ",
            "'copernicus' will fail until it is installed:\n",
            "  pip install copernicusmarine && copernicusmarine login\n",
            "If it is installed already, point R at it with:\n",
            "  options(datamatch.copernicusmarine = \"/full/path/to/copernicusmarine\")")
  }
  on.exit(options(withr_options), add = TRUE)

  invisible(shiny::runApp(app_dir, ...))
}

#' Locate the Copernicus Marine client
#'
#' `Sys.which()` is enough from a terminal and often not enough anywhere else. An
#' app launched from RStudio or any GUI inherits a minimal environment rather
#' than the shell's, so a client installed under conda is on the user's PATH and
#' not on R's. The usual install locations are checked as well, and the answer is
#' an absolute path so that nothing downstream has to search again — including
#' the parallel workers, which start with no PATH additions at all.
#'
#' @return the path to the client, or `""` when it cannot be found
#' @examples
#' copernicus_client()
#' @export
copernicus_client <- function() {
  configured <- getOption("datamatch.copernicusmarine")
  if (!is.null(configured) && nzchar(Sys.which(configured))) {
    return(unname(Sys.which(configured)))
  }
  if (!is.null(configured) && file.exists(configured)) return(configured)

  found <- unname(Sys.which("copernicusmarine"))
  if (nzchar(found)) return(found)

  candidates <- c(
    file.path(path.expand("~"), c("miniconda3", "anaconda3", "mambaforge",
                                  "miniforge3"), "bin", "copernicusmarine"),
    "/opt/homebrew/bin/copernicusmarine", "/usr/local/bin/copernicusmarine",
    file.path(path.expand("~"), ".local", "bin", "copernicusmarine")
  )
  hit <- candidates[file.exists(candidates)]
  if (length(hit) > 0) return(hit[1])
  ""
}
