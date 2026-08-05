test_that("load_zoop_data filters to the configured window and dataset", {
  config <- mock_config()
  generate_mock_zoop_data(config, n_stations = 200)

  dat <- load_zoop_data(config)

  expect_true(all(dat$year >= config$dates$years[1] & dat$year <= config$dates$years[2]))
  expect_true(all(dat$month >= config$dates$months[1] & dat$month <= config$dates$months[2]))
  expect_true(all(dat$dataset == "ECOMON"))
  expect_true(all(dat$lon >= config$study_area$bbox$xmin & dat$lon <= config$study_area$bbox$xmax))
  expect_true(all(dat$jday >= 1 & dat$jday <= 366))
})

test_that("positive longitudes are negated", {
  config <- mock_config()
  generate_mock_zoop_data(config, n_stations = 50)

  raw <- readr::read_csv(config$paths$zoop_file, show_col_types = FALSE)
  raw$lon <- abs(raw$lon)
  readr::write_csv(raw, config$paths$zoop_file)

  dat <- load_zoop_data(config)

  expect_true(all(dat$lon < 0))
})

test_that("summing all stages reproduces the precomputed total column", {
  # The database's <species>_total columns are rowSums over the stage columns, so
  # summing every stage must reproduce the total exactly.
  config <- mock_config()
  generate_mock_zoop_data(config, n_stations = 50)

  # Both sides must be the same species, so pin it rather than relying on
  # whichever species the shipped config happens to default to.
  config$species$active <- "ctyp"
  config$species$resolved <- resolve_species(config)
  by_prefix <- load_zoop_data(config)

  config$species$catalog$ctyp$column_prefix <- NULL
  config$species$catalog$ctyp$abundance_column <- "ctyp_total"
  config$species$resolved <- resolve_species(config)
  by_column <- load_zoop_data(config)

  expect_equal(by_prefix$abundance, by_column$abundance)
})

test_that("available_stages reads the stages each species actually has", {
  config <- mock_config()
  generate_mock_zoop_data(config, n_stations = 20)

  cfin_stages <- available_stages(config$paths$zoop_file, "cfin")
  ctyp_stages <- available_stages(config$paths$zoop_file, "ctyp")

  expect_true(all(c("CI", "CII", "CIII", "CIV", "CV", "CVI") %in% cfin_stages))
  expect_true("adult" %in% ctyp_stages)

  # The precomputed total is not a life stage.
  expect_false("total" %in% cfin_stages)
})

test_that("only single stages are offered, not overlapping combinations", {
  config <- mock_config()
  generate_mock_zoop_data(config, n_stations = 20)

  ctyp_stages <- available_stages(config$paths$zoop_file, "ctyp")
  pcal_stages <- available_stages(config$paths$zoop_file, "pseudo")

  # These columns span several stages and overlap the single ones.
  expect_false(any(c("CV_CVI", "IV_V", "IV_VI", "C") %in% ctyp_stages))
  expect_false(any(c("CI_IV", "C") %in% pcal_stages))
  expect_true(all(ctyp_stages %in% single_stages()))
})

test_that("cfin_CV_VI is offered as the adult stage", {
  config <- mock_config()
  generate_mock_zoop_data(config, n_stations = 20)

  cfin_stages <- available_stages(config$paths$zoop_file, "cfin")

  # ECOMON does not resolve CV from CVI for C. finmarchicus and reports the
  # combined count, which is the adult/late-stage number.
  expect_true("adult" %in% cfin_stages)
  expect_false("CV_VI" %in% cfin_stages)

  raw <- readr::read_csv(config$paths$zoop_file, show_col_types = FALSE)
  expect_equal(stage_columns(names(raw), "cfin", "adult"), "cfin_CV_VI")
})

test_that("selecting cfin adult alongside CV or CVI is rejected as double-counting", {
  config <- mock_config()
  generate_mock_zoop_data(config, n_stations = 20)
  header <- names(readr::read_csv(config$paths$zoop_file, show_col_types = FALSE))

  expect_error(stage_columns(header, "cfin", c("adult", "CV")), "more than once")
  expect_error(stage_columns(header, "cfin", c("adult", "CVI")), "more than once")

  # Non-overlapping combinations remain fine.
  expect_equal(stage_columns(header, "cfin", c("adult", "CI")),
               c("cfin_CV_VI", "cfin_CI"))
})

test_that("selecting stages sums only those columns", {
  config <- mock_config()
  generate_mock_zoop_data(config, n_stations = 50)

  config$species$active <- "cfin"
  config$species$catalog$cfin$stages <- c("CV", "CVI")
  config$species$resolved <- resolve_species(config)
  late <- load_zoop_data(config)

  config$species$catalog$cfin$stages <- NULL
  config$species$resolved <- resolve_species(config)
  all_stages <- load_zoop_data(config)

  expect_true(all(late$abundance < all_stages$abundance))

  raw <- readr::read_csv(config$paths$zoop_file, show_col_types = FALSE)
  raw <- raw[raw$dataset == "ECOMON", ]
  expect_equal(sort(late$abundance),
               sort((raw$cfin_CV + raw$cfin_CVI)[order(raw$cfin_CV + raw$cfin_CVI)]),
               tolerance = 1e-6)
})

test_that("pcal resolves to the pseudo_ columns", {
  config <- mock_config()
  generate_mock_zoop_data(config, n_stations = 50)

  config$species$active <- "pcal"
  config$species$resolved <- resolve_species(config)
  dat <- load_zoop_data(config)

  raw <- readr::read_csv(config$paths$zoop_file, show_col_types = FALSE)
  raw <- raw[raw$dataset == "ECOMON", ]
  expect_equal(sum(dat$abundance), sum(raw$pseudo_total), tolerance = 1e-6)
})

test_that("an unknown stage names the stages that do exist", {
  config <- mock_config()
  generate_mock_zoop_data(config, n_stations = 20)

  config$species$active <- "ctyp"
  config$species$catalog$ctyp$stages <- "CXX"
  config$species$resolved <- resolve_species(config)

  expect_error(validate_columns(config), "not selectable")
  expect_error(validate_columns(config), "Selectable stages")
})

test_that("summing all stages still uses the combination columns", {
  # Leaving stages empty must reproduce <prefix>_total, which is what keeps the
  # default ECOMON run working - ECOMON reports cfin only in cfin_CV_VI.
  config <- mock_config()
  generate_mock_zoop_data(config, n_stations = 20)
  header <- names(readr::read_csv(config$paths$zoop_file, show_col_types = FALSE))

  expect_true("cfin_CV_VI" %in% stage_columns(header, "cfin", NULL))
  expect_true("ctyp_CV_CVI" %in% stage_columns(header, "ctyp", NULL))
})

test_that("label_patch splits at the configured percentile", {
  config <- mock_config()
  dat <- data.frame(abundance = 1:1000)

  labeled <- label_patch(dat, config)

  threshold <- stats::quantile(1:1000, 0.9, names = FALSE)
  expect_equal(attr(labeled, "threshold"), threshold)
  # "patch" must be the first factor level so yardstick treats it as the event.
  expect_equal(levels(labeled$patch)[1], "patch")
  expect_equal(sum(labeled$patch == "patch"), sum((1:1000) >= threshold))
})

test_that("label_patch honours an absolute threshold below 1", {
  # The original inferred "percentile" from `threshold < 1`, so an absolute
  # threshold of 0.5 was silently reinterpreted as the 50th percentile.
  config <- mock_config()
  config$species$active <- "ctyp"
  config$species$catalog$ctyp$threshold <- list(type = "absolute", value = 0.5)
  config$species$resolved <- resolve_species(config)

  labeled <- label_patch(data.frame(abundance = seq(0, 10, length.out = 200)), config)

  expect_equal(attr(labeled, "threshold"), 0.5)
})

test_that("label_patch rejects degenerate abundance rather than fitting on it", {
  config <- mock_config()

  # ECOMON zero-fills stages it does not resolve, so a species with no coverage
  # yields all-zero abundance rather than NA - which no NA filter would catch.
  expect_error(label_patch(data.frame(abundance = rep(0, 200)), config),
               "zero in every selected record")
  expect_error(label_patch(data.frame(abundance = rep(7, 200)), config), "constant")
})

test_that("label_patch requires enough rows to fit", {
  config <- mock_config()

  expect_error(label_patch(data.frame(abundance = 1:50), config), "at least 100")
})
