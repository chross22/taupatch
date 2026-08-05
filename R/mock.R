#' Generate a synthetic zooplankton database
#'
#' Writes a CSV matching the schema `original/create_database.R` produces, so the
#' pipeline can be exercised end-to-end without the real survey data, which stays
#' on its owner's machine.
#'
#' Two details are copied from the real database's structure rather than invented,
#' because the pipeline's behavior depends on them:
#' \itemize{
#'   \item Stage columns that a survey does not resolve are filled with **zeros**,
#'     not NA (`create_database.R` lines 32-55 for ECOMON), so `<species>_total`
#'     collapses to the single stage ECOMON measures.
#'   \item `dataset` takes the values `ECOMON`, `ECOMON_STAGED`, `MBON`, `CPR`, so
#'     the config's `dataset_filter` is actually exercised rather than matching
#'     every row.
#' }
#'
#' Abundance is given real spatial and seasonal structure — a temperature-like
#' gradient plus a summer peak — so a model fit to it should score meaningfully
#' better than chance. A smoke test that passed on pure noise would not be testing
#' anything.
#'
#' @param config a config list, as returned by `load_config()`
#' @param n_stations number of station visits to generate per year
#' @param seed random seed
#' @return the path written, invisibly
#' @export
generate_mock_zoop_data <- function(config, n_stations = 400, seed = 42) {
  set.seed(seed)
  bbox <- config$study_area$bbox
  years <- seq(config$dates$years[1], config$dates$years[2])
  months <- seq(config$dates$months[1], config$dates$months[2])

  rows <- lapply(years, function(year) {
    lon <- stats::runif(n_stations, bbox$xmin, bbox$xmax)
    lat <- stats::runif(n_stations, bbox$ymin, bbox$ymax)
    month <- sample(months, n_stations, replace = TRUE)
    day <- sample(1:28, n_stations, replace = TRUE)

    # Planted structure: abundance rises to the north and peaks in late summer,
    # so the covariates carry real signal for the model to recover. The phase is
    # set so the sine peaks in August, matching when Gulf of Maine SST does -
    # mock values that plot to an implausible season are misleading to look at.
    lat_effect <- (lat - bbox$ymin) / (bbox$ymax - bbox$ymin)
    season_effect <- sin((month - 5) / 12 * 2 * pi)
    signal <- 3 * lat_effect + 1.5 * season_effect + stats::rnorm(n_stations, 0, 0.6)

    data.frame(
      station = paste0("MOCK", year, "_", seq_len(n_stations)),
      year = year, month = month, day = day,
      lat = round(lat, 4), lon = round(lon, 4),
      abundance_raw = exp(signal) * 100,
      dataset = sample(c("ECOMON", "ECOMON_STAGED", "MBON", "CPR"),
                       n_stations, replace = TRUE, prob = c(0.85, 0.05, 0.05, 0.05))
    )
  })
  dat <- do.call(rbind, rows)

  dat <- add_mock_stage_columns(dat)
  dat$abundance_raw <- NULL

  dir.create(dirname(config$paths$zoop_file), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(dat, config$paths$zoop_file)
  invisible(config$paths$zoop_file)
}

#' Add staged count columns to mock station data
#'
#' Reproduces the real database's column set, including its zero-fill convention
#' for unresolved stages and its `rowSums()` totals.
#'
#' @param dat mock station data with an `abundance_raw` column
#' @return `dat` with stage and total columns for all three taxa
#' @keywords internal
add_mock_stage_columns <- function(dat) {
  n <- nrow(dat)
  zero <- rep(0, n)

  # cfin is stage-resolved, as ECOMON_STAGED resolves it from c1_10m2..c6_10m2
  # (create_database.R lines 75-83). Later copepodite stages dominate, which is
  # what makes selecting a subset of stages produce a different model than
  # selecting all of them - the point of having stage selection at all.
  stage_share <- c(CI = 0.05, CII = 0.08, CIII = 0.12, CIV = 0.18, CV = 0.32, CVI = 0.25)
  for (stage in names(stage_share)) {
    dat[[paste0("cfin_", stage)]] <- dat$abundance_raw * stage_share[[stage]] *
      stats::runif(n, 0.7, 1.3)
  }
  dat$cfin_CI_IV <- zero
  # cfin_CV_VI is the adult/late-stage count (offered as `adult`), and is where
  # ECOMON puts its C. finmarchicus numbers since it does not resolve CV from CVI.
  dat$cfin_CV_VI <- dat$cfin_CV + dat$cfin_CVI

  # ctyp and pseudo carry their counts in `_adult` with the rest zero-filled,
  # as the ECOMON branch does (create_database.R lines 41-54). Selecting a
  # zero-filled stage is a real scenario the pipeline must reject clearly.
  dat$ctyp_adult <- dat$abundance_raw
  dat$ctyp_CIII <- zero; dat$ctyp_CIV <- zero; dat$ctyp_CV <- zero
  dat$ctyp_C <- zero; dat$ctyp_IV_V <- zero; dat$ctyp_IV_VI <- zero
  dat$ctyp_CVI <- zero; dat$ctyp_CV_CVI <- zero

  dat$pseudo_adult <- dat$abundance_raw * 0.7
  dat$pseudo_CII <- zero; dat$pseudo_CV <- zero; dat$pseudo_C <- zero
  dat$pseudo_CVI <- zero; dat$pseudo_CI_IV <- zero

  for (prefix in c("cfin", "ctyp", "pseudo")) {
    stage_cols <- grep(paste0("^", prefix, "_"), names(dat), value = TRUE)
    dat[[paste0(prefix, "_total")]] <- rowSums(dat[stage_cols], na.rm = TRUE)
  }
  dat
}

#' Generate synthetic environmental covariates
#'
#' Produces the same shape `datamatch::accessEnvDat()` returns, so the pipeline
#' runs identically against mock and Copernicus data. Covariates carry the same
#' latitudinal and seasonal structure planted in the mock abundances, so the model
#' has something real to learn.
#'
#' @param config a config list, as returned by `load_config()`
#' @param years years to generate
#' @param months months to generate
#' @param resolution grid spacing in degrees
#' @param seed random seed
#' @return an `sf` POINT object matching `fetch_covariates()`'s contract
#' @export
generate_mock_covariates <- function(config, years = NULL, months = NULL,
                                     resolution = 0.25, seed = 42) {
  set.seed(seed)
  bbox <- config$study_area$bbox
  period <- covariate_period(config)
  years <- years %||% period$years
  months <- months %||% period$months

  grid <- expand.grid(
    x = seq(bbox$xmin, bbox$xmax, by = resolution),
    y = seq(bbox$ymin, bbox$ymax, by = resolution)
  )

  # Generate exactly the covariates the config selects, under those names, so a
  # mock run exercises the same predictor set a Copernicus run would.
  selected <- config$covariates$selected
  if (length(selected) == 0) selected <- c("SST", "SSS")

  frames <- list()
  for (year in years) {
    for (month in months) {
      lat_effect <- (grid$y - bbox$ymin) / (bbox$ymax - bbox$ymin)
      season_effect <- sin((month - 5) / 12 * 2 * pi)
      n <- nrow(grid)

      frame <- data.frame(x = grid$x, y = grid$y)
      for (name in selected) {
        frame[[name]] <- mock_covariate_values(name, lat_effect, season_effect, n)
      }
      frame$YEAR <- year
      frame$MONTH <- month
      frame$DAY <- 15L
      frames[[length(frames) + 1]] <- frame
    }
  }

  covars <- do.call(rbind, frames)
  sf::st_as_sf(covars, coords = c("x", "y"), crs = sf::st_crs(4326))
}

#' Plausible synthetic values for a named covariate
#'
#' Values sit in each covariate's real range and units so mock output is not
#' misleading to look at. SST and CHL additionally carry the same latitudinal and
#' seasonal structure planted in the mock abundances, giving the model real signal
#' to recover; the rest are weakly structured noise.
#'
#' @param name covariate name from [copernicus_covariates()]
#' @param lat_effect scaled latitude, 0 at the south edge and 1 at the north
#' @param season_effect seasonal cycle term, ranging from -1 to 1
#' @param n number of grid points
#' @return numeric vector of length `n`
#' @keywords internal
mock_covariate_values <- function(name, lat_effect, season_effect, n) {
  noise <- function(sd) stats::rnorm(n, 0, sd)
  switch(
    name,
    SST  = 12 - 4 * lat_effect + 5 * season_effect + noise(0.3),
    SSS  = 33 + 1.5 * lat_effect + noise(0.1),
    BOTT = 8 - 2 * lat_effect + noise(0.4),
    UO   = noise(0.15),
    VO   = noise(0.15),
    SSH  = noise(0.08),
    MLD  = 30 - 15 * season_effect + abs(noise(3)),
    CHL  = pmax(0, 1.2 + 1.5 * lat_effect + 0.8 * season_effect + noise(0.3)),
    NO3  = pmax(0, 5 + 3 * lat_effect + noise(0.5)),
    O2   = 250 + 20 * lat_effect + noise(5),
    noise(1)
  )
}
