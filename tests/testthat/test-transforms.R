test_that("every transform describes itself and does exactly one thing", {
  catalog <- covariate_transforms()

  expect_gt(length(catalog), 0)
  for (name in names(catalog)) {
    entry <- catalog[[name]]
    expect_true(nzchar(entry$label %||% ""), info = name)
    expect_true(nzchar(entry$description %||% ""), info = name)
    expect_type(entry$folds_sign, "logical")
    expect_type(entry$undefined_at_zero, "logical")
    # Applied directly or estimated from the data, never both and never neither.
    expect_true(xor(is.null(entry$fn), is.null(entry$step)), info = name)
  }
})

test_that("the fixed transforms compute what they claim", {
  catalog <- covariate_transforms()
  x <- c(1, 10, 100)

  expect_equal(catalog$log1p$fn(x), log1p(x))
  expect_equal(catalog$log$fn(x), log(x))
  expect_equal(catalog$log10$fn(x), c(0, 1, 2))
  expect_equal(catalog$sqrt$fn(c(4, 9)), c(2, 3))
  expect_equal(catalog$fourth_root$fn(c(16, 81)), c(2, 3))

  # Depth is stored as negative, which is the reason abs() is there at all.
  expect_equal(catalog$log10$fn(-100), 2)
})

test_that("log_transform still means what it always meant", {
  config <- mock_config()
  config$covariates$log_transform <- c("SST", "SSS")

  expect_equal(covariate_transform_spec(config), list(log1p = c("SST", "SSS")))

  # And it merges with, rather than replaces, an explicit transform block.
  config$covariates$transform <- list(sqrt = "CHL")
  spec <- covariate_transform_spec(config)
  expect_setequal(names(spec), c("sqrt", "log1p"))
  expect_equal(spec$log1p, c("SST", "SSS"))
})

test_that("a transform undefined at zero is refused the data that has zeros", {
  entry <- covariate_transforms()$log

  # log(0) is -Inf, which normalizes to NaN and takes the whole column with it.
  expect_error(check_transform_input(c(0, 1, 2), "CHL", "log", entry),
               "undefined at zero")
  expect_error(check_transform_input(c(0, 1, 2), "CHL", "log", entry), "CHL")
  expect_true(check_transform_input(c(1, 2), "CHL", "log", entry))
})

test_that("folding the sign of a signed covariate warns", {
  entry <- covariate_transforms()$log1p

  # Uniformly negative is a sign convention - depth - and abs() is the point.
  expect_silent(check_transform_input(c(-10, -50, -200), "DEPTH", "log1p", entry))
  # Both signs is a real signed quantity, where abs() maps -2 and 2 together.
  expect_warning(check_transform_input(c(-2, 0, 2), "SST_tgrad", "log1p", entry),
                 "holds both signs")
  # Yeo-Johnson is the escape hatch, and does not fold.
  expect_silent(check_transform_input(c(-2, 0, 2), "SST_tgrad", "yeojohnson",
                                       covariate_transforms()$yeojohnson))
})

test_that("config validation rejects malformed transform blocks", {
  config <- mock_config()
  config$covariates$selected <- c("SST", "SSS")

  config$covariates$transform <- list(logten = "SST")
  expect_error(validate_covariates(config), "Unknown transform")

  config$covariates$transform <- list(sqrt = "CHL")
  expect_error(validate_covariates(config), "not selected")

  # Two transforms on one covariate would apply in list order, which nobody
  # means to ask for.
  config$covariates$transform <- list(sqrt = "SST", log10 = c("SST", "SSS"))
  expect_error(validate_covariates(config), "more than one transform")
})

test_that("the recipe applies the configured transform and honors normalize", {
  model_data <- data.frame(
    CHL = c(1, 10, 100, 1000),
    SST = c(4, 9, 16, 25),
    patch = factor(c("patch", "non_patch", "patch", "non_patch"))
  )
  config <- mock_config()
  config$covariates$transform <- list(log10 = "CHL", sqrt = "SST")
  config$covariates$normalize <- FALSE

  baked <- recipes::bake(recipes::prep(build_recipe(model_data, config)),
                          new_data = NULL)

  expect_equal(baked$CHL, c(0, 1, 2, 3))
  expect_equal(baked$SST, c(2, 3, 4, 5))

  # With normalizing on, the same columns come back centred and scaled.
  config$covariates$normalize <- TRUE
  normalized <- recipes::bake(recipes::prep(build_recipe(model_data, config)),
                              new_data = NULL)
  expect_equal(mean(normalized$CHL), 0)
  expect_equal(sd(normalized$CHL), 1)
})

test_that("an estimated transform reaches the recipe as a step", {
  model_data <- data.frame(
    CHL = c(1, 2, 3, 8, 20, 50),
    patch = factor(rep(c("patch", "non_patch"), 3))
  )
  config <- mock_config()
  config$covariates$transform <- list(yeojohnson = "CHL")
  config$covariates$normalize <- FALSE

  baked <- recipes::bake(recipes::prep(build_recipe(model_data, config)),
                          new_data = NULL)

  # The parameter is estimated, so the values are not a fixed function of the
  # input - but the long right tail must be pulled in.
  expect_lt(max(diff(sort(baked$CHL))), max(diff(sort(model_data$CHL))))
})

test_that("generate_config writes catalog names rather than Copernicus codes", {
  dir <- tempfile("configs"); dir.create(dir)
  path <- generate_config("readable", dir = dir, zoop_file = "data/absent.csv")
  written <- yaml::read_yaml(path)

  expect_equal(written$covariates$selected, c("SST", "SSS", "BOTT", "MLD", "CHL"))
  expect_null(written$covariates$copernicus)
  expect_equal(written$covariates$source, "copernicus")

  # dataset_filter is gone: the raw data has no dataset column to filter on.
  expect_null(written$columns$dataset_filter)
  expect_null(written$columns$dataset)

  # The file leads with comments saying what it is and where the values come
  # from, which yaml::write_yaml alone cannot do.
  expect_match(readLines(path)[1], "^# taupatch run config: readable")
  expect_true(any(grepl("covariate_transforms", readLines(path))))
})

test_that("the generated config is written in the style of the hand-written ones", {
  dir <- tempfile("configs"); dir.create(dir)
  lines <- readLines(generate_config("style", dir = dir, zoop_file = "data/absent.csv"))

  # Counts as integers, not 2003.0; logicals as true/false, not yes/no.
  expect_true(any(grepl("^  - 2003$", lines)))
  expect_false(any(grepl("2003\\.0", lines)))
  expect_true(any(grepl("normalize: true", lines)))
  expect_false(any(grepl(": yes$|: no$", lines)))
})

test_that("a generated config loads back, and a bad one is not left behind", {
  dir <- tempfile("configs"); dir.create(dir)

  path <- generate_config("valid", dir = dir, zoop_file = "data/absent.csv",
                          selected = c("SST", "CHL"),
                          transform = list(fourth_root = "CHL"))
  config <- load_config(path)
  expect_equal(covariate_transform_spec(config), list(fourth_root = "CHL"))

  # A config that does not validate would otherwise sit on disk looking usable.
  expect_error(generate_config("broken", dir = dir, selected = c("SST", "NOPE")),
               "Unknown covariate")
  expect_false(file.exists(file.path(dir, "broken.yaml")))
})

test_that("generate_config carries derivoce steps through", {
  dir <- tempfile("configs"); dir.create(dir)
  path <- generate_config(
    "derived", dir = dir, zoop_file = "data/absent.csv",
    selected = c("SST", "BOTT"), bathymetry = character(),
    derivoce = list(list(type = "horizontal_gradient", vars = "SST")),
    transform = list()
  )
  config <- load_config(path)

  expect_equal(derivoce_names(config), "SST_grad")
  expect_null(yaml::read_yaml(path)$covariates$bathymetry)
})

test_that("save_config round-trips a config and drops the derived species entry", {
  config <- mock_config()
  config$covariates$selected <- c("SST", "SSS")
  config$covariates$transform <- list(fourth_root = "SST")
  config$covariates$normalize <- FALSE

  path <- file.path(tempfile("cfg"), "run.yaml")
  dir.create(dirname(path))
  save_config(config, path)

  # species$resolved is derived by load_config(); writing it back would put a
  # computed field in a file meant to be edited by hand.
  expect_null(yaml::read_yaml(path)$species$resolved)

  back <- load_config(path)
  expect_equal(covariate_transform_spec(back), list(fourth_root = "SST"))
  expect_false(back$covariates$normalize)
  expect_equal(back$covariates$selected, c("SST", "SSS"))
})

test_that("save_config and generate_config produce the same shape of file", {
  dir <- tempfile("cfg"); dir.create(dir)
  generated <- generate_config("gen", dir = dir, zoop_file = "data/absent.csv")

  saved <- file.path(dir, "saved.yaml")
  save_config(load_config(generated), saved)

  expect_match(readLines(saved)[1], "^# taupatch run config: saved")
  # Block order is the order the documentation reads them in, not the order a
  # session's edits happened to leave the list in.
  blocks <- function(path) grep("^[a-z_]+:", readLines(path), value = TRUE)
  expect_equal(blocks(saved), blocks(generated))
})
