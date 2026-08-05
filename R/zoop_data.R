#' Load zooplankton station data
#'
#' Reads the zooplankton database CSV, keeping only the columns the config
#' declares, and filters to the configured years, months, source datasets, and
#' study-area bounding box. Abundance for the active species comes either from a
#' named column or by summing every column matching a stage prefix.
#'
#' @param config a config list, as returned by `load_config()`
#' @return a tibble with `lon`, `lat`, `year`, `month`, `day`, `jday`, and
#'   `abundance`, one row per station visit
#' @export
load_zoop_data <- function(config) {
  if (!file.exists(config$paths$zoop_file)) {
    stop("Zooplankton data file not found: ", config$paths$zoop_file, call. = FALSE)
  }
  validate_columns(config)

  cols <- config$columns
  species <- config$species$resolved

  raw <- readr::read_csv(config$paths$zoop_file, show_col_types = FALSE, progress = FALSE)

  abundance <- species_abundance(raw, species)

  dat <- tibble::tibble(
    lon = raw[[cols$lon]],
    lat = raw[[cols$lat]],
    year = raw[[cols$year]],
    month = raw[[cols$month]],
    day = raw[[cols$day]],
    abundance = abundance
  )
  if (!is.null(cols$dataset_filter)) {
    dat$dataset <- raw[[cols$dataset]]
  }

  # Longitudes in the source database have repeatedly come through with the sign
  # dropped; both create_database.R and format_model_data.R corrected it independently.
  dat$lon[!is.na(dat$lon) & dat$lon > 0] <- -dat$lon[!is.na(dat$lon) & dat$lon > 0]

  dat <- dat |>
    dplyr::filter(
      !is.na(.data$lon), !is.na(.data$lat), !is.na(.data$abundance),
      .data$year >= config$dates$years[1], .data$year <= config$dates$years[2],
      .data$month >= config$dates$months[1], .data$month <= config$dates$months[2],
      .data$lon >= config$study_area$bbox$xmin, .data$lon <= config$study_area$bbox$xmax,
      .data$lat >= config$study_area$bbox$ymin, .data$lat <= config$study_area$bbox$ymax
    )

  if (!is.null(cols$dataset_filter)) {
    dat <- dat |> dplyr::filter(.data$dataset %in% cols$dataset_filter)
  }

  if (nrow(dat) == 0) {
    stop("No zooplankton records remain after filtering. Check dates.years/dates.months, ",
         "study_area.bbox, and columns.dataset_filter against the data.", call. = FALSE)
  }

  dat$jday <- as.integer(format(
    as.Date(paste(dat$year, dat$month, dat$day, sep = "-")), "%j"
  ))

  dat
}

#' Extract a species' abundance from the raw database
#'
#' Supports both forms the database offers: a precomputed total column, or the
#' per-stage columns that total was built from. The prefix form generalizes what
#' `original/create_database.R` hardcodes once per taxon.
#'
#' @param raw the raw database data frame
#' @param species the resolved species entry from `load_config()`
#' @return a numeric vector of abundances
#' @keywords internal
species_abundance <- function(raw, species) {
  if (!is.null(species$abundance_column)) {
    return(as.numeric(raw[[species$abundance_column]]))
  }

  stage_cols <- stage_columns(names(raw), species$column_prefix, species$stages)
  rowSums(as.data.frame(raw[stage_cols]), na.rm = TRUE)
}

#' Individually resolved life stages
#'
#' The copepodite stages plus the adult stage. Selecting these is unambiguous:
#' they never overlap, so summing any subset counts each animal once.
#'
#' The database also holds combination columns spanning several stages
#' (`cfin_CV_VI`, `pseudo_CI_IV`, `ctyp_IV_VI`, and the unstaged `ctyp_C`).
#' Those are deliberately not offered for selection, because they overlap the
#' single stages — summing `CV` together with `CV_VI` would count the same
#' animals twice.
#'
#' @return character vector of single-stage codes
#' @export
single_stages <- function() {
  c("CI", "CII", "CIII", "CIV", "CV", "CVI", "adult")
}

#' List the life stages a database holds for a species
#'
#' Reads the available stages off the data rather than assuming a fixed set,
#' because the database's stage columns differ per species: `cfin` resolves `CI`
#' through `CVI`, while `ctyp` and `pseudo` carry `adult` and only some
#' copepodite stages. A hardcoded list would offer stages that do not exist for
#' a given species.
#'
#' @param zoop_file path to the zooplankton database CSV
#' @param column_prefix the species' column prefix in the database, e.g. `"pseudo"`
#' @param single_only when `TRUE` (the default), lists only individually resolved
#'   stages (see [single_stages()]); when `FALSE`, also lists the overlapping
#'   combination columns
#' @return character vector of stage codes, e.g. `c("CI", "CII", "adult")`
#' @examples
#' \dontrun{
#' available_stages("data/zooplankton_database.csv", "cfin")
#' #> "CI" "CII" "CIII" "CIV" "CV" "CVI"
#' available_stages("data/zooplankton_database.csv", "ctyp")
#' #> "CIII" "CIV" "CV" "CVI" "adult"
#' }
#' @export
available_stages <- function(zoop_file, column_prefix, single_only = TRUE) {
  header <- names(readr::read_csv(zoop_file, n_max = 0, show_col_types = FALSE,
                                   progress = FALSE))
  if (single_only) {
    return(names(stage_column_map(header, column_prefix)))
  }
  cols <- species_stage_pool(header, column_prefix)
  sub(paste0("^", column_prefix, "_"), "", cols)
}

#' Stage columns that are aliased to a single-stage name
#'
#' Some species report a stage under a column name that does not look like a
#' single stage. `cfin_CV_VI` is the adult/late-stage count — it is how ECOMON
#' reports *C. finmarchicus*, which does not resolve CV from CVI — so it is
#' offered as `adult`, matching how `ctyp` and `pseudo` name theirs.
#'
#' `spans` records which single stages the column covers, so a selection mixing
#' an alias with a stage it already contains can be rejected instead of
#' double-counting.
#'
#' @param column_prefix the species' column prefix in the database
#' @return named list of `list(column=, spans=)`, keyed by the stage name to
#'   present, or `NULL` when the species needs no aliases
#' @keywords internal
stage_alias_map <- function(column_prefix) {
  switch(column_prefix,
         cfin = list(adult = list(column = "CV_VI", spans = c("CV", "CVI"))),
         NULL)
}

#' Stage columns for a species, excluding precomputed totals
#'
#' @param header column names of the database
#' @param column_prefix the species' column prefix in the database
#' @param single_only restrict to individually resolved stages, including aliases
#' @return character vector of column names
#' @keywords internal
species_stage_pool <- function(header, column_prefix, single_only = FALSE) {
  cols <- grep(paste0("^", column_prefix, "_"), header, value = TRUE)
  # The database carries a precomputed `<prefix>_total` alongside the stage
  # columns it was summed from, and it matches the prefix too. Including it
  # would double every abundance.
  cols <- cols[!grepl("_total$", cols)]

  if (single_only) {
    suffixes <- sub(paste0("^", column_prefix, "_"), "", cols)
    aliased <- vapply(stage_alias_map(column_prefix), function(a) a$column,
                      character(1))
    cols <- cols[suffixes %in% single_stages() | suffixes %in% aliased]
  }
  cols
}

#' Map selectable stage names to their database columns
#'
#' @param header column names of the database
#' @param column_prefix the species' column prefix in the database
#' @return named character vector of column names, keyed by stage name
#' @keywords internal
stage_column_map <- function(header, column_prefix) {
  cols <- species_stage_pool(header, column_prefix, single_only = TRUE)
  suffixes <- sub(paste0("^", column_prefix, "_"), "", cols)

  aliases <- stage_alias_map(column_prefix)
  for (stage in names(aliases)) {
    suffixes[suffixes == aliases[[stage]]$column] <- stage
  }
  stats::setNames(cols, suffixes)
}

#' Single stages covered by each selectable stage
#'
#' @param column_prefix the species' column prefix in the database
#' @param stages stage names to expand
#' @return named list mapping each stage to the single stages it covers
#' @keywords internal
stage_spans <- function(column_prefix, stages) {
  aliases <- stage_alias_map(column_prefix)
  stats::setNames(lapply(stages, function(s) {
    if (!is.null(aliases[[s]])) aliases[[s]]$spans else s
  }), stages)
}

#' Resolve requested life stages to database columns
#'
#' With no stages requested, every stage column is summed — including the
#' combination columns — which reproduces the database's `<prefix>_total`. This
#' matters for ECOMON, where `cfin`'s counts live in the combination column
#' `cfin_CV_VI` and the single stages are zero-filled.
#'
#' An explicit selection, by contrast, is restricted to individually resolved
#' stages, since combination columns overlap them and summing a mix would
#' double-count.
#'
#' @param header column names of the database
#' @param column_prefix the species' column prefix in the database
#' @param stages stage codes to select; `NULL` sums every stage
#' @return character vector of column names to sum
#' @keywords internal
stage_columns <- function(header, column_prefix, stages = NULL) {
  pool <- species_stage_pool(header, column_prefix)
  if (length(pool) == 0) {
    stop("No columns in the data start with '", column_prefix, "_'.", call. = FALSE)
  }
  if (is.null(stages) || length(stages) == 0) {
    return(pool)
  }

  selectable <- stage_column_map(header, column_prefix)

  unknown <- setdiff(stages, names(selectable))
  if (length(unknown) > 0) {
    stop("Stage(s) not selectable for '", column_prefix, "': ",
         paste(unknown, collapse = ", "),
         "\nSelectable stages: ", paste(names(selectable), collapse = ", "),
         "\n(Columns spanning several stages are not individually selectable, ",
         "since they overlap the single stages. Leave stages empty to sum ",
         "everything, or set abundance_column instead.)",
         call. = FALSE)
  }

  # `adult` for cfin is the CV+CVI combination column, so selecting it alongside
  # CV or CVI would count those animals twice.
  spans <- stage_spans(column_prefix, stages)
  covered <- unlist(spans, use.names = FALSE)
  duplicated_stages <- unique(covered[duplicated(covered)])
  if (length(duplicated_stages) > 0) {
    stop("Overlapping stage selection for '", column_prefix, "': ",
         paste(stages, collapse = ", "), " together cover ",
         paste(duplicated_stages, collapse = ", "),
         " more than once. Drop one of them.", call. = FALSE)
  }

  unname(selectable[stages])
}

#' Label high-abundance patches
#'
#' Classifies each station as inside or outside a high-abundance patch, using
#' either a percentile of the observed abundance distribution or an absolute
#' abundance value.
#'
#' @param dat station data from `load_zoop_data()`
#' @param config a config list, as returned by `load_config()`
#' @param min_rows minimum rows required to fit a usable model
#' @return `dat` with an added `patch` factor whose first level is `"patch"`, and
#'   a `threshold` attribute recording the abundance value used
#' @export
label_patch <- function(dat, config, min_rows = 100) {
  species <- config$species$resolved
  threshold <- resolve_threshold(dat$abundance, species)

  dat$patch <- factor(
    ifelse(dat$abundance >= threshold, "patch", "non_patch"),
    levels = c("patch", "non_patch")
  )

  if (nrow(dat) < min_rows) {
    stop("Only ", nrow(dat), " records available for '", species$name,
         "'; need at least ", min_rows, " to fit a model.", call. = FALSE)
  }
  if (nlevels(droplevels(dat$patch)) != 2) {
    stop("Threshold ", signif(threshold, 6), " puts every record in one class for '",
         species$name, "'. Lower the threshold or widen the data selection.", call. = FALSE)
  }

  attr(dat, "threshold") <- threshold
  dat
}

#' Resolve a threshold specification to an abundance value
#'
#' The database zero-fills life stages a survey does not resolve rather than
#' NA-filling them (`original/create_database.R` lines 32-55 for ECOMON), so a
#' species with no coverage in the selected data yields a column of zeros rather
#' than NAs, which no NA filter would catch. That is checked explicitly here.
#'
#' @param abundance numeric vector of abundances
#' @param species the resolved species entry from `load_config()`
#' @return the abundance value separating patch from non-patch
#' @keywords internal
resolve_threshold <- function(abundance, species) {
  if (all(abundance == 0)) {
    stop("Abundance for '", species$name, "' is zero in every selected record. ",
         "This usually means the source dataset does not resolve this species.",
         call. = FALSE)
  }
  if (length(unique(abundance)) == 1) {
    stop("Abundance for '", species$name, "' is constant (", unique(abundance),
         ") across every selected record; no threshold can separate patches.",
         call. = FALSE)
  }

  if (species$threshold$type == "percentile") {
    unname(stats::quantile(abundance, probs = species$threshold$value, na.rm = TRUE))
  } else {
    species$threshold$value
  }
}
