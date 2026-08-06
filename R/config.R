#' Load and validate a taupatch run config
#'
#' Reads a run config YAML (see `inst/configs/`), resolves paths relative to
#' `paths.project_dir`, and validates the parts that are cheap to check before a
#' run rather than midway through one: the active species exists in the catalog,
#' each species resolves to an abundance column, thresholds are well-formed, and
#' the declared columns actually exist in the zooplankton CSV.
#'
#' @param path path to a config YAML file
#' @return the parsed config list with `paths` resolved to absolute paths and a
#'   derived `species$resolved` entry describing the active species
#' @export
load_config <- function(path) {
  if (!file.exists(path)) {
    stop("Config file not found: ", path, call. = FALSE)
  }
  config <- yaml::read_yaml(path)

  config <- resolve_config_paths(config, path)
  config <- apply_config_defaults(config)

  validate_species(config)
  validate_dates(config)
  validate_study_area(config)
  validate_covariates(config)

  config$species$resolved <- resolve_species(config)

  # The CSV may not exist yet for mock runs, where generate_mock_zoop_data()
  # writes it after the config is loaded. Defer to load_zoop_data() in that case.
  if (file.exists(config$paths$zoop_file)) {
    validate_columns(config)
  }

  config
}

#' Resolve config paths relative to the project directory
#'
#' `paths.project_dir` itself is resolved relative to the config file's own
#' location, so a config with `project_dir: '.'` works regardless of the caller's
#' working directory.
#'
#' @param config a parsed config list
#' @param config_path path the config was read from
#' @return `config` with `paths` entries as absolute paths
#' @keywords internal
resolve_config_paths <- function(config, config_path) {
  project_dir <- config$paths$project_dir %||% "."
  if (!is_absolute_path(project_dir)) {
    project_dir <- file.path(dirname(normalizePath(config_path)), project_dir)
  }
  config$paths$project_dir <- normalizePath(project_dir, mustWork = TRUE)

  for (key in c("zoop_file", "output_dir", "covariate_dir")) {
    value <- config$paths[[key]]
    if (!is.null(value) && !is_absolute_path(value)) {
      config$paths[[key]] <- file.path(config$paths$project_dir, value)
    }
  }
  config
}

#' Check whether a path is absolute
#'
#' @param path a file path string
#' @return `TRUE` if `path` starts with `/`, `~`, or a Windows drive letter
#' @keywords internal
is_absolute_path <- function(path) {
  grepl("^(/|~|[A-Za-z]:[\\\\/])", path)
}

#' Fill in config defaults
#'
#' Defaults target ECOMON, which is what this model runs on essentially all of
#' the time, so a minimal config is a species name and a data path.
#'
#' @param config a parsed config list
#' @return `config` with missing optional fields populated
#' @keywords internal
apply_config_defaults <- function(config) {
  config$columns <- modifyList(
    list(lat = "lat", lon = "lon", year = "year", month = "month", day = "day",
         dataset = "dataset", dataset_filter = "ECOMON"),
    config$columns %||% list()
  )
  config$model <- modifyList(
    list(engine = "ranger", trees = 500, mtry = NULL, min_n = NULL,
         cv_folds = 10, tune = FALSE, seed = 42),
    config$model %||% list()
  )
  config$projection <- modifyList(
    list(write_geotiff = TRUE, write_png = TRUE, overwrite = TRUE),
    config$projection %||% list()
  )
  # Projection defaults to the training window, so a config that does not
  # distinguish them behaves as it did before they could differ.
  config$projection$years <- config$projection$years %||% config$dates$years
  config$projection$months <- config$projection$months %||% config$dates$months
  config$covariates <- modifyList(
    list(source = "copernicus", derived = "jday", derivoce = list(),
         log_transform = character()),
    config$covariates %||% list()
  )
  config
}

#' Validate the species block
#'
#' @param config a parsed config list
#' @return `TRUE` invisibly; errors otherwise
#' @keywords internal
validate_species <- function(config) {
  catalog <- config$species$catalog
  if (length(catalog) == 0) {
    stop("config species.catalog is empty; define at least one species.", call. = FALSE)
  }
  active <- config$species$active
  if (is.null(active) || !(active %in% names(catalog))) {
    stop("species.active ('", active %||% "<missing>", "') must be one of species.catalog: ",
         paste(names(catalog), collapse = ", "), call. = FALSE)
  }

  for (name in names(catalog)) {
    entry <- catalog[[name]]
    if (!is.null(entry$abundance_column) && !is.null(entry$column_prefix)) {
      stop("species.catalog.", name,
           " sets both 'abundance_column' and 'column_prefix'; use one or the other.",
           call. = FALSE)
    }
    if (!is.null(entry$stages) && !is.null(entry$abundance_column)) {
      stop("species.catalog.", name,
           " sets 'stages', which requires 'column_prefix' rather than 'abundance_column'.",
           call. = FALSE)
    }
    validate_threshold(entry$threshold, name)
  }
  invisible(TRUE)
}

#' Validate one species' threshold specification
#'
#' The original pipeline inferred percentile-vs-absolute from whether the value
#' was below 1, which silently misreads any real abundance threshold under 1.
#' The type is explicit here instead.
#'
#' @param threshold a `list(type=, value=)`
#' @param species_name species name, for error messages
#' @return `TRUE` invisibly; errors otherwise
#' @keywords internal
validate_threshold <- function(threshold, species_name) {
  if (is.null(threshold$type) || is.null(threshold$value)) {
    stop("species.catalog.", species_name,
         ".threshold must set both 'type' and 'value'.", call. = FALSE)
  }
  if (!(threshold$type %in% c("percentile", "absolute"))) {
    stop("species.catalog.", species_name, ".threshold.type must be 'percentile' or 'absolute', got '",
         threshold$type, "'.", call. = FALSE)
  }
  if (threshold$type == "percentile" && (threshold$value <= 0 || threshold$value >= 1)) {
    stop("species.catalog.", species_name,
         ".threshold.value must be strictly between 0 and 1 for type 'percentile', got ",
         threshold$value, ".", call. = FALSE)
  }
  if (threshold$type == "absolute" && threshold$value <= 0) {
    stop("species.catalog.", species_name,
         ".threshold.value must be positive for type 'absolute', got ",
         threshold$value, ".", call. = FALSE)
  }
  invisible(TRUE)
}

#' Validate the training and projection date ranges
#'
#' @param config a parsed config list
#' @return `TRUE` invisibly; errors otherwise
#' @keywords internal
validate_dates <- function(config) {
  validate_date_range(config$dates$years, config$dates$months, "dates")
  validate_date_range(config$projection$years, config$projection$months, "projection")
  invisible(TRUE)
}

#' Validate one year/month range pair
#'
#' @param years two-element year range
#' @param months two-element month range
#' @param label config section name, for error messages
#' @return `TRUE` invisibly; errors otherwise
#' @keywords internal
validate_date_range <- function(years, months, label) {
  if (length(years) != 2 || years[1] > years[2]) {
    stop(label, ".years must be [start, end] with start <= end.", call. = FALSE)
  }
  if (length(months) != 2 || months[1] > months[2] || months[1] < 1 || months[2] > 12) {
    stop(label, ".months must be [start, end] within 1-12 with start <= end.",
         call. = FALSE)
  }
  invisible(TRUE)
}

#' Years and months covariates are needed for
#'
#' The union of the training and projection windows: training needs covariates to
#' match to stations, projection needs them to predict over. Fetching the union as
#' two sets rather than one spanning range avoids downloading the gap between
#' windows that are far apart.
#'
#' @param config a config list, as returned by `load_config()`
#' @return `list(years=, months=)`, each a sorted vector
#' @keywords internal
covariate_period <- function(config) {
  list(
    years = sort(union(seq(config$dates$years[1], config$dates$years[2]),
                       seq(config$projection$years[1], config$projection$years[2]))),
    months = sort(union(seq(config$dates$months[1], config$dates$months[2]),
                        seq(config$projection$months[1], config$projection$months[2])))
  )
}

#' Validate the study-area bounding box
#'
#' @param config a parsed config list
#' @return `TRUE` invisibly; errors otherwise
#' @keywords internal
validate_study_area <- function(config) {
  bbox <- config$study_area$bbox
  missing <- setdiff(c("xmin", "xmax", "ymin", "ymax"), names(bbox))
  if (length(missing) > 0) {
    stop("study_area.bbox is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  if (bbox$xmin >= bbox$xmax || bbox$ymin >= bbox$ymax) {
    stop("study_area.bbox must satisfy xmin < xmax and ymin < ymax.", call. = FALSE)
  }
  invisible(TRUE)
}

#' Validate the covariates block
#'
#' @param config a parsed config list
#' @return `TRUE` invisibly; errors otherwise
#' @keywords internal
validate_covariates <- function(config) {
  source <- config$covariates$source
  valid <- c("copernicus", "local_netcdf", "mock")
  if (!(source %in% valid)) {
    stop("covariates.source must be one of ", paste(valid, collapse = ", "),
         ", got '", source, "'.", call. = FALSE)
  }
  selected <- config$covariates$selected
  bathymetry <- config$covariates$bathymetry
  known <- c(names(copernicus_covariates()), names(bathymetry_covariates()))

  if (length(selected) > 0) {
    unknown <- setdiff(selected, names(copernicus_covariates()))
    if (length(unknown) > 0) {
      stop("Unknown covariate(s) in covariates.selected: ",
           paste(unknown, collapse = ", "),
           "\nAvailable: ", paste(names(copernicus_covariates()), collapse = ", "),
           "\n(Static seafloor covariates go under covariates.bathymetry: ",
           paste(names(bathymetry_covariates()), collapse = ", "), ")", call. = FALSE)
    }
  } else if (source == "copernicus" && length(config$covariates$copernicus) == 0 &&
             length(bathymetry) == 0) {
    stop("covariates.source is 'copernicus' but neither covariates.selected nor ",
         "covariates.copernicus names anything to fetch.", call. = FALSE)
  }

  if (length(bathymetry) > 0) {
    unknown <- setdiff(bathymetry, names(bathymetry_covariates()))
    if (length(unknown) > 0) {
      stop("Unknown covariate(s) in covariates.bathymetry: ",
           paste(unknown, collapse = ", "),
           "\nAvailable: ", paste(names(bathymetry_covariates()), collapse = ", "),
           call. = FALSE)
    }
  }

  validate_derivoce(config)

  log_unknown <- setdiff(config$covariates$log_transform,
                         c(selected, bathymetry, config$covariates$derived,
                           derivoce_names(config)))
  if (length(log_unknown) > 0) {
    stop("covariates.log_transform names covariates that are not selected: ",
         paste(log_unknown, collapse = ", "), call. = FALSE)
  }
  if (source == "local_netcdf" && is.null(config$paths$covariate_dir)) {
    stop("covariates.source is 'local_netcdf' but paths.covariate_dir is not set.",
         call. = FALSE)
  }
  invisible(TRUE)
}

#' Describe the active species
#'
#' Resolves the active species to the concrete abundance definition the rest of
#' the pipeline uses, so no downstream code re-reads the catalog.
#'
#' `column_prefix` defaults to the catalog key, so a species whose database
#' columns are named after it needs no prefix at all. Setting it explicitly
#' aliases a preferred name onto different column names — `pcal` is the one case
#' in this database, where the columns are `pseudo_*`.
#'
#' @param config a parsed config list
#' @return `list(name=, abundance_column=, column_prefix=, stages=, threshold=)`,
#'   where exactly one of `abundance_column`/`column_prefix` is non-`NULL`
#' @keywords internal
resolve_species <- function(config) {
  name <- config$species$active
  entry <- config$species$catalog[[name]]
  list(
    name = name,
    abundance_column = entry$abundance_column,
    column_prefix = if (is.null(entry$abundance_column)) {
      entry$column_prefix %||% name
    },
    stages = entry$stages,
    threshold = entry$threshold
  )
}

#' Check the config's declared columns against the CSV header
#'
#' Reads the header only, never any data rows, so a config can be validated
#' against a dataset without loading it.
#'
#' @param config a config list, as returned by `load_config()`
#' @return `TRUE` invisibly; errors listing every missing column otherwise
#' @export
validate_columns <- function(config) {
  header <- names(readr::read_csv(config$paths$zoop_file, n_max = 0,
                                   show_col_types = FALSE, progress = FALSE))

  required <- unlist(config$columns[c("lat", "lon", "year", "month", "day")])
  if (!is.null(config$columns$dataset_filter)) {
    required <- c(required, config$columns$dataset)
  }

  species <- config$species$resolved %||% resolve_species(config)
  if (!is.null(species$abundance_column)) {
    required <- c(required, species$abundance_column)
  }

  missing <- setdiff(unname(required), header)
  if (length(missing) > 0) {
    stop("Columns declared in config are missing from '", config$paths$zoop_file, "': ",
         paste(missing, collapse = ", "),
         "\nColumns present: ", paste(header, collapse = ", "), call. = FALSE)
  }

  if (!is.null(species$column_prefix)) {
    # Resolves the requested stages too, so an unknown stage name is reported
    # up front with the list of stages the database actually has.
    stage_columns(header, species$column_prefix, species$stages)
  }

  invisible(TRUE)
}

#' Write a taupatch run config
#'
#' Defaults reproduce a working ECOMON run over the Northeast US shelf, so a new
#' config is normally one call with a species name. The default bounding box
#' matches the extent the original pipeline cropped its projections to.
#'
#' @param name config name; the file is written to `<dir>/<name>.yaml`
#' @param zoop_file path to the zooplankton database CSV
#' @param output_dir where run outputs are written
#' @param species named list of species definitions; defaults to the three taxa in
#'   the original database (`cfin`, `ctyp`, `pseudo`) at the 90th percentile
#' @param active_species which species to model
#' @param years two-element `c(start, end)` year range
#' @param months two-element `c(start, end)` month range
#' @param bbox named list with `xmin`/`xmax`/`ymin`/`ymax`
#' @param dataset_filter values of the `dataset` column to keep; `NULL` keeps all
#' @param covariate_source one of `"copernicus"`, `"local_netcdf"`, `"mock"`
#' @param copernicus_datasets list of Copernicus product/dataset/variable specs
#' @param derivoce list of derived-covariate steps; see [derivoce_covariates()]
#' @param log_transform covariate columns to log-transform in the recipe
#' @param cv_folds number of cross-validation folds
#' @param trees number of trees in the random forest
#' @param dir directory to write the config into
#' @return the path written, invisibly
#' @export
generate_config <- function(name,
                            zoop_file = "data/zooplankton_database.csv",
                            output_dir = file.path("output", name),
                            species = default_species_catalog(),
                            active_species = "cfin",
                            years = c(2003, 2017),
                            months = c(1, 12),
                            bbox = list(xmin = -71, xmax = -65, ymin = 40, ymax = 45),
                            dataset_filter = "ECOMON",
                            covariate_source = "copernicus",
                            copernicus_datasets = default_copernicus_datasets(),
                            derivoce = list(),
                            log_transform = character(),
                            cv_folds = 10,
                            trees = 500,
                            dir = "inst/configs") {
  config <- list(
    paths = list(project_dir = ".", zoop_file = zoop_file, output_dir = output_dir),
    columns = list(lat = "lat", lon = "lon", year = "year", month = "month",
                   day = "day", dataset = "dataset", dataset_filter = dataset_filter),
    species = list(active = active_species, catalog = species),
    dates = list(years = years, months = months),
    study_area = list(bbox = bbox),
    covariates = list(source = covariate_source, copernicus = copernicus_datasets,
                      derived = "jday", derivoce = derivoce,
                      log_transform = log_transform),
    model = list(engine = "ranger", trees = trees, cv_folds = cv_folds,
                 tune = FALSE, seed = 42),
    projection = list(write_geotiff = TRUE, write_png = TRUE, overwrite = TRUE)
  )

  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(dir, paste0(name, ".yaml"))
  yaml::write_yaml(config, out_path)
  invisible(out_path)
}

#' Default species catalog
#'
#' The three taxa the original zooplankton database resolves, each thresholded at
#' the 90th percentile as in Ross et al. (2023).
#'
#' Each entry uses `column_prefix` with no `stages`, meaning "sum every life
#' stage" — equivalent to the `<species>_total` column, but letting a run narrow
#' to particular stages without changing the catalog. `pcal` is the one species
#' whose preferred name differs from its database prefix (`pseudo_*`), so it
#' declares the alias explicitly.
#'
#' @return a named list suitable for `species.catalog`
#' @export
default_species_catalog <- function() {
  percentile_90 <- list(type = "percentile", value = 0.9)
  list(
    cfin = list(column_prefix = "cfin", threshold = percentile_90),
    ctyp = list(column_prefix = "ctyp", threshold = percentile_90),
    pcal = list(column_prefix = "pseudo", threshold = percentile_90)
  )
}

#' Default Copernicus datasets
#'
#' Monthly physical ocean variables from the global reanalysis: potential
#' temperature, salinity, and the two current components. Chlorophyll lives in a
#' separate biogeochemistry product and is left for the user to add, since which
#' BGC product is appropriate depends on the year range.
#'
#' @return a list of product/dataset/variable specs for `covariates.copernicus`
#' @export
default_copernicus_datasets <- function() {
  list(list(
    product_id = "GLOBAL_MULTIYEAR_PHY_001_030",
    dataset_id = "cmems_mod_glo_phy_my_0.083deg_P1M-m",
    vars = c("thetao", "so", "uo", "vo"),
    depth = c(0, 1)
  ))
}

# Null-coalescing operator. Defined here rather than relying on base R's, which
# only exists from R 4.4 onward.
`%||%` <- function(x, y) if (is.null(x)) y else x
