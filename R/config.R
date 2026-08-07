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
  validate_model(config)
  validate_dates(config)
  validate_study_area(config)
  validate_covariates(config)
  validate_uncertainty(config)

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
  # `type` is deliberately not defaulted. resolve_model_type() falls back to a
  # random forest when it is absent, and can read an older config's `engine`
  # instead - a default here would overwrite that inference with "rf" and make
  # `engine: xgboost` silently fit a forest.
  config$model <- modifyList(
    list(trees = 500, mtry = NULL, min_n = NULL,
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
    list(source = "copernicus", derived = "jday",
         transform = list(), normalize = TRUE, log_transform = character()),
    config$covariates %||% list()
  )
  # Not modifyList defaults. It recurses when both sides are lists and merges
  # by name, and these blocks are *unnamed* sequences of steps - so the
  # recursion finds no names to merge and yields the empty default back,
  # erasing the block the config actually asked for.
  config$covariates$derivoce <- config$covariates$derivoce %||% list()
  config$covariates$prejoin <- config$covariates$prejoin %||% list()
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

#' Validate the model block
#'
#' The type and its tuning, checked at load rather than after the covariates
#' have been downloaded and the stations matched.
#'
#' @param config a parsed config list
#' @return `TRUE` invisibly; errors otherwise
#' @keywords internal
validate_model <- function(config) {
  type <- resolve_model_type(config)
  entry <- model_types()[[type]]

  if (isTRUE(config$model$tune) && length(entry$tunable) == 0) {
    stop("model.tune is true, but ", entry$label, " has no hyperparameters to ",
         "tune. Set model.tune to false, or choose a type that does: ",
         paste(names(Filter(function(m) length(m$tunable) > 0, model_types())),
               collapse = ", "), call. = FALSE)
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

  climate <- config$covariates$climate
  if (length(climate) > 0) {
    unknown <- setdiff(climate, names(climate_index_covariates()))
    if (length(unknown) > 0) {
      stop("Unknown climate index/indices in covariates.climate: ",
           paste(unknown, collapse = ", "),
           "\nAvailable: ",
           paste(names(climate_index_covariates()), collapse = ", "),
           call. = FALSE)
    }
  }

  excluded <- config$covariates$exclude
  if (length(excluded) > 0) {
    unknown <- setdiff(excluded, c(selected, bathymetry))
    if (length(unknown) > 0) {
      stop("covariates.exclude names covariates that are not fetched: ",
           paste(unknown, collapse = ", "),
           "\nIt drops a fetched covariate from the predictors; it cannot drop ",
           "one that was never selected.", call. = FALSE)
    }
  }

  validate_prejoin(config)
  validate_derivoce(config)
  # A gap-filling source does not survive the join, so it cannot be transformed
  # or named by a later step as though it were a predictor.
  validate_transforms(config, c(setdiff(selected, prejoin_dropped(config)),
                                bathymetry, config$covariates$derived,
                                config$covariates$climate,
                                derivoce_names(config)))
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
#' config is normally one call with a name. The default bounding box matches the
#' extent the original pipeline cropped its projections to
#' (`original/load_covars.R:147`).
#'
#' Covariates are named the way the rest of the package names them — `SST`, not
#' `thetao` on `cmems_mod_glo_phy_my_0.083deg_P1M-m` — so a generated config reads
#' like the shipped example and can be edited without consulting the Copernicus
#' catalog. `covariate_info()` lists the names; the raw `covariates.copernicus`
#' block is still accepted by hand for a dataset the catalog does not cover.
#'
#' The file is loaded back and validated before the path is returned, so a
#' mistyped covariate or transform is an error now rather than five minutes into
#' a run.
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
#' @param covariate_source one of `"copernicus"`, `"local_netcdf"`, `"mock"`
#' @param selected time-varying covariate names; see [copernicus_covariates()]
#' @param bathymetry static seafloor covariate names; see [bathymetry_covariates()]
#' @param prejoin list of per-covariate steps applied before products are
#'   joined; see [prejoin_steps()]
#' @param climate climate index names; see [climate_index_covariates()]
#' @param derivoce list of derived-covariate steps; see [derivoce_covariates()]
#' @param transform named list of transform to covariate names; see
#'   [covariate_transforms()]
#' @param normalize whether to center and scale the predictors
#' @param type which model to fit; see [model_types()]
#' @param trees number of trees in the random forest
#' @param cv_folds number of cross-validation folds
#' @param dir directory to write the config into
#' @return the path written, invisibly
#' @examples
#' \dontrun{
#' generate_config("cfin_gom")
#' generate_config("ctyp_shelf", active_species = "ctyp",
#'                 selected = c("SST", "SSS", "CHL"),
#'                 transform = list(fourth_root = "CHL"))
#' }
#' @seealso [covariate_info()] for the covariate names, [load_config()] to read
#'   the result back
#' @export
generate_config <- function(name,
                            zoop_file = "data/zooplankton_database.csv",
                            output_dir = file.path("output", name),
                            species = default_species_catalog(),
                            active_species = "cfin",
                            years = c(2003, 2017),
                            months = c(1, 12),
                            bbox = list(xmin = -76, xmax = -65, ymin = 35, ymax = 45),
                            covariate_source = "copernicus",
                            selected = c("SST", "SSS", "BOTT", "MLD", "CHL"),
                            bathymetry = c("DEPTH", "SLOPE"),
                            prejoin = list(),
                            climate = character(),
                            derivoce = list(),
                            transform = list(log1p = c("CHL", "DEPTH")),
                            normalize = TRUE,
                            type = "rf",
                            trees = 500,
                            cv_folds = 10,
                            dir = "inst/configs") {
  covariates <- list(source = covariate_source, selected = as.character(selected))
  # Omitted rather than written empty, so the generated file shows only the
  # blocks the run actually uses.
  if (length(bathymetry) > 0) covariates$bathymetry <- as.character(bathymetry)
  if (length(prejoin) > 0) covariates$prejoin <- prejoin
  if (length(climate) > 0) covariates$climate <- as.character(climate)
  covariates$derived <- "jday"
  if (length(derivoce) > 0) covariates$derivoce <- derivoce
  if (length(transform) > 0) covariates$transform <- transform
  covariates$normalize <- normalize

  config <- list(
    paths = list(project_dir = ".", zoop_file = zoop_file, output_dir = output_dir),
    columns = list(lat = "lat", lon = "lon", year = "year", month = "month",
                   day = "day"),
    species = list(active = active_species, catalog = species),
    # Counts are written as integers so the file reads `2003` rather than
    # `2003.0`; a config is meant to be edited by hand after this.
    dates = list(years = as.integer(years), months = as.integer(months)),
    study_area = list(bbox = bbox),
    covariates = covariates,
    model = list(type = type, trees = as.integer(trees),
                 cv_folds = as.integer(cv_folds), tune = FALSE, seed = 42L),
    projection = list(write_geotiff = TRUE, write_png = TRUE, overwrite = TRUE)
  )

  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(dir, paste0(name, ".yaml"))
  save_config(config, out_path)

  # A config that does not load is worse than none: it sits on disk looking
  # usable. Removed before the error surfaces, so a failed call leaves nothing.
  tryCatch(load_config(out_path), error = function(e) {
    unlink(out_path)
    stop(conditionMessage(e), call. = FALSE)
  })
  invisible(out_path)
}

#' Serialize a config to YAML
#'
#' `yaml::as.yaml()` writes logicals as `yes`/`no`. That is valid YAML 1.1 and
#' round-trips correctly, but every config in this package is written `true` /
#' `false`, and a generated file that does not look like the hand-written ones is
#' half the reason the generator was worth avoiding.
#'
#' @param config a config list
#' @return a YAML string
#' @keywords internal
write_config_yaml <- function(config) {
  yaml::as.yaml(config, handlers = list(
    logical = function(x) {
      out <- ifelse(x, "true", "false")
      class(out) <- "verbatim"
      out
    }
  ))
}

#' Write a config list to a YAML file
#'
#' The counterpart to [load_config()], and what both [generate_config()] and the
#' app's download button use, so a config saved from a session and one written
#' programmatically are the same file.
#'
#' `species$resolved` is dropped. `load_config()` derives it on the way in, and
#' writing it back would put a computed field in a file meant to be edited by
#' hand — and one that silently overrides the catalog it was derived from.
#'
#' @param config a config list
#' @param path where to write it
#' @param header whether to lead the file with orientation comments
#' @return `path`, invisibly
#' @examples
#' \dontrun{
#' config <- load_config("my_run.yaml")
#' config$model$trees <- 1000
#' save_config(config, "my_run_1000.yaml")
#' }
#' @export
save_config <- function(config, path, header = TRUE) {
  config$species$resolved <- NULL

  # Written in the order the documentation reads them, rather than whatever
  # order the list happens to be in after a session's worth of edits.
  blocks <- c("paths", "columns", "species", "dates", "study_area", "covariates",
              "model", "projection")
  config <- config[c(intersect(blocks, names(config)),
                     setdiff(names(config), blocks))]

  text <- write_config_yaml(config)
  if (isTRUE(header)) {
    text <- c(config_header(sub("\\.ya?ml$", "", basename(path))), text)
  }
  writeLines(text, path)
  invisible(path)
}

#' Header comments for a generated config
#'
#' `yaml::write_yaml()` writes no comments, and an uncommented config gives a
#' reader no way in. This is not the shipped example's per-field commentary, but
#' it does say what the file is and which functions list the values its fields
#' accept.
#'
#' @param name the config's name
#' @return a character vector of comment lines
#' @keywords internal
config_header <- function(name) {
  c(
    paste0("# taupatch run config: ", name),
    paste0("# Written by taupatch::generate_config() on ", Sys.Date(), "."),
    "#",
    "# Every field can be edited by hand. To see what the covariate fields",
    "# accept:",
    "#",
    "#   taupatch::covariate_info()          # selected, bathymetry",
    "#   taupatch::derivoce_covariates()     # derivoce",
    "#   taupatch::covariate_transforms()    # transform",
    "#   taupatch::available_stages(file, species)   # species.catalog.*.stages",
    "#",
    "# inst/configs/cfin_gom.yaml is the same thing with every field explained.",
    ""
  )
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
