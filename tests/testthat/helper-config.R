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
