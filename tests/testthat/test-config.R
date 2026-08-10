test_that("load_config resolves paths and the active species", {
  config <- mock_config()

  expect_true(is_absolute_path(config$paths$output_dir))
  expect_equal(config$species$resolved$name, "cfin")
  expect_equal(config$species$resolved$column_prefix, "cfin")
  expect_equal(config$species$resolved$threshold$type, "percentile")
})

test_that("column_prefix defaults to the species key but can alias it", {
  config <- mock_config()

  # cfin/ctyp columns are named after the species, so no alias is needed.
  config$species$active <- "cfin"
  expect_equal(resolve_species(config)$column_prefix, "cfin")

  # pcal is the one species whose database columns use a different prefix.
  config$species$active <- "pcal"
  expect_equal(resolve_species(config)$column_prefix, "pseudo")

  # An entry with no column_prefix at all falls back to its key.
  config$species$catalog$newsp <- list(threshold = list(type = "percentile", value = 0.9))
  config$species$active <- "newsp"
  expect_equal(resolve_species(config)$column_prefix, "newsp")
})

# A config file on disk, so the YAML parser is actually exercised. Building the
# list in R skips the only place these bugs can happen.
write_yaml_text <- function(lines) {
  path <- tempfile(fileext = ".yaml")
  writeLines(lines, path)
  path
}

test_that("a key that spells a boolean keeps its own name", {
  # YAML 1.1 reads a bare `n` as false, so `n: 2` would name the key FALSE and
  # a lag_covariate step would silently fall back to one month.
  path <- write_yaml_text(c("steps:", "  - type: lag_covariate", "    n: 2"))

  parsed <- read_config_yaml(path)

  expect_equal(names(parsed$steps[[1]]), c("type", "n"))
  expect_equal(parsed$steps[[1]]$n, 2)
})

test_that("every YAML 1.1 boolean spelling survives as a key", {
  path <- write_yaml_text(c("n: 1", "y: 2", "no: 3", "yes: 4", "off: 5",
                            "on: 6", "true: 7", "false: 8", "N: 9", "Off: 10"))

  parsed <- read_config_yaml(path)

  expect_equal(names(parsed), c("n", "y", "no", "yes", "off", "on", "true",
                                "false", "N", "Off"))
  expect_equal(unname(unlist(parsed)), 1:10)
})

test_that("a boolean in a value position is still a boolean", {
  # The other half of the fix. Recovering key spellings must not turn the
  # config's actual switches into strings.
  path <- write_yaml_text(c("model:", "  tune: false", "  select: yes",
                            "covariates:", "  normalize: true", "  thin: off",
                            "flags: [true, false]"))

  parsed <- read_config_yaml(path)

  expect_identical(parsed$model$tune, FALSE)
  expect_identical(parsed$model$select, TRUE)
  expect_identical(parsed$covariates$normalize, TRUE)
  expect_identical(parsed$covariates$thin, FALSE)
  # A sequence of them collapses to an atomic vector, which drops attributes -
  # which is why the source text is carried in the string rather than beside it.
  expect_identical(parsed$flags, c(TRUE, FALSE))
})

test_that("an empty config field survives the boolean walk", {
  # The walk rebuilds every list it descends into, and an empty YAML field
  # parses to NULL. Rebuilding by assigning back into the list - `x[] <- lapply`
  # rather than replacing it - drops NULL elements entirely, which would make
  # `"mtry" %in% names(config$model)` false for a field the file does mention.
  path <- write_yaml_text(c("model:", "  mtry:", "  tune: false",
                            "covariates:", "  transform:",
                            "  normalize: true"))

  parsed <- read_config_yaml(path)

  expect_equal(names(parsed$model), c("mtry", "tune"))
  expect_null(parsed$model$mtry)
  expect_equal(names(parsed$covariates), c("transform", "normalize"))
  expect_identical(parsed$covariates$normalize, TRUE)
})

test_that("a quoted string that spells a boolean stays a string", {
  path <- write_yaml_text(c("species:", "  active: 'true'", "  label: \"no\"",
                            "note: not a bool"))

  parsed <- read_config_yaml(path)

  expect_identical(parsed$species$active, "true")
  expect_identical(parsed$species$label, "no")
  expect_identical(parsed$note, "not a bool")
})

test_that("the shipped config's lag reaches derivoce with the lag it asks for", {
  # The end-to-end version: the bug was invisible in cfin_gom.yaml precisely
  # because its `n: 1` matched the fallback, so this pins the whole path.
  path <- system.file("configs", "cfin_gom.yaml", package = "taupatch")
  if (!nzchar(path)) path <- test_path("..", "..", "inst", "configs", "cfin_gom.yaml")

  config <- read_config_yaml(path)
  lag <- Filter(function(s) identical(s$type, "lag_covariate"),
                config$covariates$derivoce)[[1]]

  expect_equal(lag$n, 1)
  expect_false("FALSE" %in% names(lag))
})

test_that("a config the package writes is read correctly by a plain parser", {
  # yaml::as.yaml quotes these keys on the way out, so the round trip does not
  # depend on the reader knowing about any of this.
  path <- tempfile(fileext = ".yaml")
  save_config(list(covariates = list(derivoce = list(
    list(type = "lag_covariate", vars = "SST", n = 2)
  ))), path, header = FALSE)

  plain <- yaml::read_yaml(path)

  expect_equal(plain$covariates$derivoce[[1]]$n, 2)
})

test_that("defaults target ECOMON", {
  config <- apply_config_defaults(list())

  expect_equal(config$columns$dataset_filter, "ECOMON")
  expect_equal(config$columns$lat, "lat")
  # model.type is deliberately absent from the defaults so resolve_model_type()
  # can still read an older config's `engine`; a default would overwrite that
  # inference and make `engine: xgboost` silently fit a forest.
  expect_null(config$model$type)
  expect_equal(resolve_model_type(config), "rf")
  expect_false(config$model$tune)
})

test_that("an unknown active species is rejected", {
  config <- mock_config()
  config$species$active <- "not_a_species"

  expect_error(validate_species(config), "must be one of species.catalog")
})

test_that("a species cannot set both an abundance column and a column prefix", {
  config <- mock_config()
  config$species$catalog$ctyp$abundance_column <- "ctyp_total"

  expect_error(validate_species(config), "use one or the other")
})

test_that("stages require a column prefix rather than a total column", {
  config <- mock_config()
  config$species$catalog$ctyp$column_prefix <- NULL
  config$species$catalog$ctyp$abundance_column <- "ctyp_total"
  config$species$catalog$ctyp$stages <- "CV"

  expect_error(validate_species(config), "requires 'column_prefix'")
})

test_that("thresholds are validated by type, not by magnitude", {
  # The original inferred percentile-vs-absolute from `threshold < 1`, which
  # misreads any real abundance threshold below 1. Type is explicit now, so a
  # small absolute threshold is valid and a percentile outside (0,1) is not.
  expect_error(validate_threshold(list(type = "percentile", value = 1.5), "x"),
               "strictly between 0 and 1")
  expect_error(validate_threshold(list(type = "bogus", value = 0.5), "x"),
               "must be 'percentile' or 'absolute'")
  expect_error(validate_threshold(list(type = "percentile"), "x"), "both 'type' and 'value'")

  expect_true(validate_threshold(list(type = "absolute", value = 0.5), "x"))
  expect_true(validate_threshold(list(type = "percentile", value = 0.9), "x"))
})

test_that("validate_columns names every missing column", {
  config <- mock_config()
  generate_mock_zoop_data(config, n_stations = 20)

  expect_true(validate_columns(config))

  config$columns$lat <- "latitude"
  config$columns$lon <- "longitude"
  expect_error(validate_columns(config), "latitude")
  expect_error(validate_columns(config), "longitude")
})

test_that("the projection window defaults to the training window", {
  config <- mock_config()

  expect_equal(config$projection$years, config$dates$years)
  expect_equal(config$projection$months, config$dates$months)
})

test_that("the projection window can differ from the training window", {
  config <- mock_config()
  config$projection$years <- c(2020, 2021)
  config$projection$months <- c(1, 3)

  expect_true(validate_dates(config))
  expect_equal(config$dates$years, c(2018, 2019))
})

test_that("covariates are fetched for the union of both windows", {
  config <- mock_config()
  config$dates$years <- c(2018, 2019)
  config$dates$months <- c(6, 8)
  config$projection$years <- c(2021, 2021)
  config$projection$months <- c(1, 2)

  period <- covariate_period(config)

  # Both windows must be covered: training needs covariates to match to
  # stations, projection needs them to predict over.
  expect_true(all(c(2018, 2019, 2021) %in% period$years))
  expect_true(all(c(1, 2, 6, 7, 8) %in% period$months))
  # The gap between the windows is not fetched.
  expect_false(2020 %in% period$years)
  expect_false(4 %in% period$months)
})

test_that("an invalid projection window is reported as such", {
  config <- mock_config()
  config$projection$years <- c(2021, 2019)

  expect_error(validate_dates(config), "projection.years")
})

test_that("study area and covariate source are validated", {
  config <- mock_config()

  config$study_area$bbox$xmin <- config$study_area$bbox$xmax + 1
  expect_error(validate_study_area(config), "xmin < xmax")

  config <- mock_config()
  config$covariates$source <- "ftp"
  expect_error(validate_covariates(config), "must be one of")
})
