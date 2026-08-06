# Loads the shipped mock config and redirects its paths into a temp directory,
# so tests never write into the installed package or the working tree.
mock_config <- function(dir = tempfile("taupatch")) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  path <- system.file("configs", "mock_test.yaml", package = "taupatch")
  if (!nzchar(path)) path <- testthat::test_path("..", "..", "inst", "configs", "mock_test.yaml")

  config <- load_config(path)
  config$paths$zoop_file <- file.path(dir, "mock_zooplankton.csv")
  config$paths$output_dir <- file.path(dir, "output")
  config
}

# Modeling data as fit_patch_model() expects it: stations with covariates
# attached and patches labeled. Runs the same path the pipeline does, so tests
# exercise real data rather than a hand-built frame that might drift from it.
labeled_mock_data <- function(config = mock_config()) {
  generate_mock_zoop_data(config)
  dat <- load_zoop_data(config)
  env_dat <- fetch_covariates(config)
  dat <- attach_covariates(dat, env_dat, config)
  dat <- add_derived_covariates(dat, config)
  label_patch(dat, config)
}
