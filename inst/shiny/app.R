library(shiny)
library(taupatch)

`%||%` <- function(x, y) if (is.null(x)) y else x

# A relative path in the box is relative to where the app was launched, which is
# what someone typing "data/zoop.csv" means.
is_absolute <- function(path) grepl("^(/|~|[A-Za-z]:[\\\\/])", path)

# A collapsible sidebar block. The sidebar had grown to about six screens of
# controls in one column, and a control you have to scroll past four times is
# effectively hidden. <details> rather than a package's accordion: it collapses
# natively, needs no dependency, and keeps the whole form in the DOM so nothing
# reactive stops updating while a section is shut.
sidebar_section <- function(title, ..., open = TRUE) {
  tags$details(
    class = "tp-section", open = if (open) NA else NULL,
    tags$summary(title), div(class = "tp-section-body", ...)
  )
}

# Drops the trailing ".0" that a 0.01-step slider otherwise produces, so the
# note reads "top 15%" rather than "top 15.0%".
format_percent <- function(x) format(round(x, 1), trim = TRUE, drop0trailing = TRUE)

# Config values the launcher passes through, so the app opens on a sensible
# starting config rather than an empty form.
#
# Falls back to the shipped mock config when the option is unset, which is the
# case when this directory is run directly - `shiny::runApp("inst/shiny")` after
# load_all(), the usual way to iterate on the app without reinstalling. Without
# the fallback every base_config$... is NULL and the first sliderInput() fails
# with a message that says nothing about the real cause.
# Resolved here rather than only in run_taupatch_app(), because the app is also
# launched by pointing shiny at this directory, and because the launcher's
# search can be the thing that misses. copernicus_client() looks past PATH into
# the usual conda locations, which is the case that matters: an R session
# started from RStudio has the user's conda install on their PATH and not on
# R's, and a parallel worker spawned from it has less environment still.
local({
  client <- taupatch::copernicus_client()
  if (nzchar(client)) {
    options(datamatch.copernicusmarine = client)
  }
})

base_config <- getOption("taupatch.app_config")
if (is.null(base_config)) {
  fallback <- system.file("configs", "mock_test.yaml", package = "taupatch")
  if (!nzchar(fallback)) fallback <- "../configs/mock_test.yaml"
  base_config <- taupatch::load_config(fallback)
}

# "SST - Sea surface temperature (degrees C)" in the dropdown, "SST" as the value.
covariate_labels <- function(info) {
  stats::setNames(
    info$name,
    paste0(info$name, " - ", info$label, " (", info$units, ")")
  )
}

covariate_reference <- covariate_info(include_derived = FALSE)
bathymetry_names <- names(bathymetry_covariates())
covariate_choices <- covariate_labels(
  covariate_reference[!(covariate_reference$name %in% bathymetry_names), ]
)
bathymetry_choices <- covariate_labels(
  covariate_reference[covariate_reference$name %in% bathymetry_names, ]
)

# "NAO - North Atlantic Oscillation" in the dropdown, "NAO" as the value.
climate_catalog <- climate_index_covariates()
climate_choices <- stats::setNames(
  names(climate_catalog),
  paste0(names(climate_catalog), " - ",
         vapply(climate_catalog, function(e) e$label, character(1)))
)

# "rf - Random forest" in the dropdown, "rf" as the value.
model_type_catalog <- model_types()
model_type_choices <- stats::setNames(
  names(model_type_catalog),
  vapply(model_type_catalog, function(m) m$label, character(1))
)

# "log1p - log(1 + |x|)" in the dropdown, "log1p" as the value.
transform_catalog <- covariate_transforms()
transform_choices <- stats::setNames(
  names(transform_catalog),
  paste0(names(transform_catalog), " - ",
         vapply(transform_catalog, function(e) e$label, character(1)))
)

# The corner notification is easy to miss and small. "old" is Shiny's
# full-width bar across the top of the page, which is what a run lasting
# twenty minutes deserves.
shinyOptions(progress.style = "old")

ui <- fluidPage(
  tags$head(tags$style(HTML("
    /* A tiled copy of the header photo, dropped almost all the way out, over a
       soft gradient. Subtle enough to read as texture rather than as a second
       image competing with the one beside the title. */
    .tp-header { display: flex; align-items: center; gap: 20px; flex-wrap: wrap;
                 position: relative; overflow: hidden;
                 padding: 16px 20px; margin-bottom: 18px;
                 border: 1px solid #dce6ec; border-radius: 8px;
                 background: linear-gradient(135deg, #eaf3f8 0%, #f8fbfd 55%,
                                             #e9f1f6 100%); }
    .tp-header::after { content: ''; position: absolute; inset: 0;
                        background-image: url('calanus.jpg');
                        background-size: 170px; background-repeat: repeat;
                        opacity: 0.05; pointer-events: none; }
    .tp-header > * { position: relative; z-index: 1; }
    .tp-header-figure { margin: 0; flex: 0 0 auto; }
    /* Cropped to a banner strip and biased upward, so the copepod's body fills
       the frame rather than the empty background below it. */
    .tp-header-photo { height: 78px; width: 220px; object-fit: cover;
                       object-position: 50% 40%; border-radius: 6px;
                       display: block;
                       box-shadow: 0 1px 4px rgba(20, 60, 80, 0.18); }
    .tp-header-credit { font-size: 10px; color: #7b8a93; margin-top: 3px;
                        line-height: 1.3; max-width: 220px; }
    .tp-header-title { margin: 0; font-size: 44px; font-weight: 700;
                       letter-spacing: -1px; line-height: 1.05;
                       color: #14343f; }
    .tp-header-sub { color: #55707c; margin: 7px 0 0; font-size: 15px; }

    /* The full-width progress bar, made tall enough to read at a glance and to
       fit the percentage and stage name it now carries. */
    .shiny-progress .progress { height: 22px; margin-bottom: 4px; }
    .shiny-progress .progress-bar { height: 22px; }
    .shiny-progress .progress-message { font-size: 15px; font-weight: 600; }
    .shiny-progress .progress-detail { font-size: 13px; color: #55707c; }
    @media (max-width: 700px) { .tp-header-photo { width: 100%; } }

    .tp-section { border-bottom: 1px solid #e3e3e3; padding: 2px 0 6px; }
    .tp-section > summary { cursor: pointer; font-size: 15px; font-weight: 600;
                            padding: 8px 2px; list-style: none;
                            display: flex; align-items: center; gap: 6px; }
    .tp-section > summary::-webkit-details-marker { display: none; }
    .tp-section > summary::before { content: \"\\25B8\"; color: #888;
                                     transition: transform 0.12s; }
    .tp-section[open] > summary::before { transform: rotate(90deg); }
    .tp-section > summary:hover { color: #2c7fb8; }
    .tp-section-body { padding: 2px 2px 8px; }
    .tp-section-body .form-group { margin-bottom: 10px; }
  "))),

  # ionRangeSlider measures its track when it initializes. A slider created by
  # renderUI is measured before the container has its final width, so the handle
  # lands at the far left even though the value is correct. Re-running update()
  # after the panel renders makes it recompute against the real width.
  # Leaflet measures its container when it initializes. The Maps tab is hidden at
  # that point, so the map is built against a zero-height box and paints blank
  # once the tab is shown. invalidateSize() makes it re-measure against the real
  # box. Same reason the ionRangeSlider above needs re-running.
  tags$head(tags$script(HTML("
    $(document).on('shiny:value', function(e) {
      if (e.name !== 'threshold_input') return;
      setTimeout(function() {
        var slider = $('#threshold_value').data('ionRangeSlider');
        if (slider) slider.update();
      }, 50);
    });

    function taupatchResizeMap() {
      setTimeout(function() {
        if (typeof HTMLWidgets === 'undefined') return;
        var widget = HTMLWidgets.find('#map');
        if (widget && widget.getMap) widget.getMap().invalidateSize();
      }, 250);
    }

    // Bootstrap 3 and 4/5 name this event differently; bind both so the fix
    // does not depend on which Bootstrap version Shiny happens to ship.
    $(document).on('shown.bs.tab shown.bs.tab.data-api', taupatchResizeMap);
    $(document).on('shiny:value', function(e) {
      if (e.name === 'map') taupatchResizeMap();
    });
  "))),

  div(
    class = "tp-header",
    tags$figure(
      class = "tp-header-figure",
      tags$img(src = "calanus.jpg", class = "tp-header-photo",
               alt = "Microscopy image of the copepod Calanus finmarchicus"),
      tags$figcaption(
        class = "tp-header-credit",
        tags$em("Calanus finmarchicus"), " Photo: Cameron R. Thompson"
      )
    ),
    div(
      h1("taupatch", class = "tp-header-title"),
      p("Monthly habitat suitability for high-abundance zooplankton patches",
        class = "tp-header-sub")
    )
  ),

  sidebarLayout(
    sidebarPanel(
      width = 3,
      sidebar_section(
        "Data",
        textInput("zoop_path", "Path to a CSV on this machine",
                  value = "", placeholder = "data/zooplankton_database.csv"),
        shinyFiles::shinyFilesButton("zoop_browse", "Browse...",
                                     title = "Choose a zooplankton CSV",
                                     multiple = FALSE, class = "btn-sm"),
        div(style = "height: 8px;"),
        uiOutput("data_status")
      ),

      sidebar_section(
        "Species",
        # Choices come from the loaded file rather than the config catalog: an
        # export carries most of a hundred taxa and any of them can be modelled.
        selectInput("species", "Species", choices = names(base_config$species$catalog),
                    selected = base_config$species$active),
        uiOutput("stage_picker"),
        selectInput("threshold_type", "Threshold type",
                    choices = c("percentile", "absolute"),
                    selected = base_config$species$resolved$threshold$type),
        uiOutput("threshold_input")
      ),

      sidebar_section(
        "Training window", open = FALSE,
        helpText("Which observations the model is fitted on."),
        sliderInput("years", "Years",
                    min = 1977, max = as.integer(format(Sys.Date(), "%Y")),
                    value = base_config$dates$years, step = 1, sep = ""),
        # Fifty years across a sidebar column is about three years per pixel,
        # so the slider cannot be landed on a particular one. The boxes are the
        # precise way in; the two stay in step with each other.
        fluidRow(
          column(6, numericInput("year_from", "From", min = 1977,
                                 max = as.integer(format(Sys.Date(), "%Y")),
                                 value = base_config$dates$years[1], step = 1)),
          column(6, numericInput("year_to", "To", min = 1977,
                                 max = as.integer(format(Sys.Date(), "%Y")),
                                 value = base_config$dates$years[2], step = 1))
        ),
        sliderInput("months", "Months", min = 1, max = 12,
                    value = base_config$dates$months, step = 1)
      ),

      sidebar_section(
        "Projection window", open = FALSE,
        helpText("Which months are mapped. Need not match the training window -",
                 "fitting on a long history and projecting a recent period is normal."),
        checkboxInput("projection_same", "Same as training window",
                      value = identical(base_config$projection$years, base_config$dates$years) &&
                        identical(base_config$projection$months, base_config$dates$months)),
        conditionalPanel(
          "!input.projection_same",
          sliderInput("proj_years", "Years",
                      min = 1977, max = as.integer(format(Sys.Date(), "%Y")),
                      value = base_config$projection$years, step = 1, sep = ""),
          sliderInput("proj_months", "Months", min = 1, max = 12,
                      value = base_config$projection$months, step = 1)
        )
      ),

      sidebar_section(
        "Study area", open = FALSE,
        fluidRow(
          column(6, numericInput("xmin", "West", base_config$study_area$bbox$xmin)),
          column(6, numericInput("xmax", "East", base_config$study_area$bbox$xmax))
        ),
        fluidRow(
          column(6, numericInput("ymin", "South", base_config$study_area$bbox$ymin)),
          column(6, numericInput("ymax", "North", base_config$study_area$bbox$ymax))
        )
      ),

      sidebar_section(
        "Covariates",
        uiOutput("covariate_label"),
        selectInput("covariates", NULL, multiple = TRUE,
                    choices = covariate_choices,
                    selected = base_config$covariates$selected %||% c("SST", "SSS")),
        # character(0), not NULL: with NULL, selectize falls back to selecting the
        # first choice, which would silently opt every run into a NOAA download.
        selectInput("bathymetry", "Seafloor (static)", multiple = TRUE,
                    choices = bathymetry_choices,
                    selected = base_config$covariates$bathymetry %||% character(0)),
        # Choices depend on what is selected above, so they are filled in by an
        # observer rather than listed here.
        selectInput("derived", "Derived", multiple = TRUE, choices = character(0),
                    selected = character(0)),
        uiOutput("derived_note"),
        selectInput("climate", "Climate indices", multiple = TRUE,
                    choices = climate_choices,
                    selected = base_config$covariates$climate %||% character(0)),
        uiOutput("climate_note"),
        # An offset is a GAM term, so offering it for the others would be
        # offering something that could not be used.
        conditionalPanel(
          "input.model_type == 'gam'",
          selectInput("offset", "Offset (GAM)", choices = c("none" = ""),
                      selected = ""),
          conditionalPanel(
            "input.offset != ''",
            selectInput("offset_transform", NULL,
                        choices = c("as is" = "none", "log" = "log"),
                        selected = "log")
          ),
          helpText("A term entered with its coefficient fixed at 1 rather than",
                   "estimated - sampling effort, or volume filtered. It is on",
                   "the link scale, so log is usually what you want.")
        ),
        # Choices are narrowed to what is actually selected above, by the observer
        # in the server. Offering unselected covariates here would let a config
        # name a transform for something the run never fetches, which config
        # validation rejects.
        tags$label("Transforms", class = "control-label"),
        uiOutput("transform_rows"),
        checkboxInput("normalize", "Centre and scale predictors",
                      value = !isFALSE(base_config$covariates$normalize)),
        actionLink("show_dictionary", "Covariate dictionary \u2192"),
        helpText("Units, resolutions, and definitions for every covariate.")
      ),

      sidebar_section(
        "Model",
        selectInput("model_type", "Type", choices = model_type_choices,
                    selected = taupatch:::resolve_model_type(base_config)),
        uiOutput("model_type_note"),
        # Trees mean nothing to a GLM or a GAM, so the control is not offered
        # for them rather than being offered and ignored.
        conditionalPanel(
          "input.model_type == 'rf' || input.model_type == 'brt'",
          numericInput("trees", "Trees", value = base_config$model$trees, min = 1)
        ),
        conditionalPanel(
          "input.model_type == 'gam'",
          selectInput("gam_bs", "Spline basis", choices = gam_bases(),
                      selected = base_config$model$bs %||% "tp"),
          selectInput("gam_method", "Smoothing method", choices = gam_methods(),
                      selected = base_config$model$method %||% "GCV.Cp"),
          selectInput("gam_family", "Link",
                      choices = c("logit", "probit", "cloglog", "cauchit", "log"),
                      selected = base_config$model$family %||% "logit"),
          checkboxInput("gam_select", "Let smooths shrink to zero",
                        value = isTRUE(base_config$model$select_features)),
          helpText("The family is binomial - the response is patch or not - so",
                   "the choice is its link. cloglog is asymmetric, which suits a",
                   "rare positive class.")
        ),
        numericInput("cv_folds", "CV folds", value = base_config$model$cv_folds, min = 2)
      ),

      hr(),
      actionButton("run", "Run model", class = "btn-primary", width = "100%"),
      br(), br(),
      downloadButton("download_config", "Download config (.yaml)",
                     style = "width: 100%;"),
      helpText("Saves the settings above as a config file, so a run you arrived",
               "at by clicking can be repeated with run_taupatch().")
    ),

    mainPanel(
      width = 9,
      tabsetPanel(
        id = "main_tabs",
tabPanel("Config", br(), verbatimTextOutput("config_yaml")),
        tabPanel("Zooplankton data", br(),
                 p("The stations themselves, before any model touches them.",
                   "A study area drawn wider than the survey, a year that",
                   "sampled half the shelf, or an abundance field that is mostly",
                   "zeros are all visible here and invisible in a metrics table."),
                 uiOutput("zoop_status"),
                 fluidRow(
                   column(5,
                          h4("Summary"),
                          tableOutput("zoop_summary")),
                   column(7,
                          h4("Where the stations are"),
                          helpText("Coloured by abundance on a log scale, since",
                                   "it spans orders of magnitude."),
                          plotOutput("zoop_map", height = "420px"))
                 ),
                 br(),
                 h4("Abundance over the record"),
                 helpText("Every station at its own month, so the seasonal cycle",
                          "and the drift between years read together."),
                 plotOutput("zoop_series", height = "320px"),
                 br(),
                 h4("Distribution"),
                 helpText("The threshold that separates patch from non-patch is",
                          "drawn on, so you can see how much of the data falls",
                          "either side of it before fitting."),
                 plotOutput("zoop_distribution", height = "300px")),
        tabPanel("Covariate trends", br(),
                 p("Study-area mean of each covariate over the run's period."),
                 uiOutput("heatmap_controls"),
                 plotOutput("covariate_heatmap", height = "480px",
                            hover = hoverOpts("heatmap_hover", delay = 80,
                                              delayType = "debounce")),
                 uiOutput("heatmap_value"),
                 br(),
                 h4("Where the covariate is"),
                 helpText("The field the model was given, drawn where it is. A",
                          "covariate that failed to download, arrived on the",
                          "wrong grid, or is masked over the wrong water shows",
                          "here and not in a monthly mean. Missing cells are",
                          "grey, which is what a patchy projection is asking",
                          "about."),
                 uiOutput("covariate_map_controls"),
                 plotOutput("covariate_map", height = "520px"),
                 br(),
                 h4("Seasonal cycle"),
                 helpText("Each year drawn as its own line, so a year that",
                          "departs from the usual cycle stands out and a gap in",
                          "the record reads as a missing line rather than as a",
                          "value."),
                 plotOutput("covariate_seasonal", height = "360px"),
                 br(),
                 h4("Year to year"),
                 helpText("Annual mean across the selected months, which is the",
                          "view that shows drift over the record."),
                 plotOutput("covariate_annual", height = "300px")),
        tabPanel("Results", br(),
                 h4("Cross-validated performance"),
                 helpText("Threshold-dependent metrics are shown at both the",
                          "default 0.5 cutoff and the cutoff that maximises TSS.",
                          "With only a tenth of stations patches, 0.5 calls",
                          "almost nothing a patch and understates the model."),
                 tableOutput("metrics"),
                 h4("Variable importance"), plotOutput("importance", height = "300px"),
                 h4("Threshold"), verbatimTextOutput("threshold")),
        tabPanel("Diagnostics", br(),
                 p("Drawn from held-out cross-validation folds, so these describe",
                   "performance on data the model did not see."),
                 uiOutput("diagnostic_note"),
                 fluidRow(
                   column(6, plotOutput("roc_plot", height = "380px")),
                   column(6, plotOutput("pr_plot", height = "380px"))
                 ),
                 br(),
                 fluidRow(
                   column(6, plotOutput("calibration_plot", height = "380px")),
                   column(6, plotOutput("threshold_plot", height = "380px"))
                 ),
                 br(),
                 h4("Partial effects"),
                 uiOutput("partial_effects_note"),
                 plotOutput("partial_effects", height = "460px"),
                 uiOutput("model_specific")),
        tabPanel("Maps", br(),
                 uiOutput("map_controls"),
                 leaflet::leafletOutput("map", height = "600px")),
        tabPanel("Log", br(), verbatimTextOutput("log")),
        # Last, and reached from the sidebar link, because it is reference
        # material consulted while choosing covariates rather than a step in
        # the run.
        tabPanel("Covariate dictionary", br(),
                 p("Every covariate the pipeline can use. Click one for its full",
                   "definition and the dataset it comes from."),
                 uiOutput("covariate_reference"))
      )
    )
  )
)

server <- function(input, output, session) {
  run_result <- reactiveVal(NULL)
  run_log <- reactiveVal("")

  # The database's stage columns differ per species - cfin carries CI..CVI while
  # ctyp and pseudo carry `adult` and combination columns - so the choices are
  # read from the data rather than from a fixed CI-CVI list.
  # A typed range, when it is one. Half-finished edits - blank, or backwards
  # while the second box is still being changed - fall back to the slider
  # rather than being treated as a range nobody asked for.
  typed_years <- function(from, to, slider) {
    if (is.null(from) || is.null(to) || is.na(from) || is.na(to)) return(slider)
    if (from > to) return(slider)
    c(as.integer(from), as.integer(to))
  }

  # The slider and the two boxes are one value shown twice, so each follows the
  # other. Guarded on equality, or they would bounce updates back and forth.
  observeEvent(input$years, {
    if (!identical(input$year_from, input$years[1])) {
      updateNumericInput(session, "year_from", value = input$years[1])
    }
    if (!identical(input$year_to, input$years[2])) {
      updateNumericInput(session, "year_to", value = input$years[2])
    }
  }, ignoreInit = TRUE)

  observeEvent(c(input$year_from, input$year_to), {
    from <- input$year_from
    to <- input$year_to
    if (is.null(from) || is.null(to) || is.na(from) || is.na(to)) return()
    # A typed range the wrong way round is a half-finished edit, not an error.
    if (from > to) return()
    if (!identical(c(from, to), input$years)) {
      updateSliderInput(session, "years", value = c(from, to))
    }
  }, ignoreInit = TRUE)

  # Every taxon the loaded file carries, not only the ones the config was set
  # up for. A formatted export holds the whole survey.
  file_species <- reactive({
    # Read from the raw file when there is one: it names its taxa by their
    # units, which is exact, where a formatted file can only be guessed at.
    source_path <- if (isTRUE(formatted_zoop()$formatted)) {
      zoop_input()
    } else {
      zoop_path()
    }
    if (!file.exists(source_path)) {
      return(data.frame(species = character(), shorthand = character(),
                        form = character(), stages = character(),
                        stringsAsFactors = FALSE))
    }
    tryCatch(available_species(source_path),
             error = function(e) data.frame(species = character(),
                                            shorthand = character(),
                                            form = character(),
                                            stages = character(),
                                            stringsAsFactors = FALSE))
  })

  observe({
    found <- file_species()
    catalog <- names(base_config$species$catalog)

    # Labelled with the full header name, valued by the shorthand, so the
    # dropdown reads as "cfin - CALANUS_FINMARCHICUS" and is searchable by
    # either. selectize makes the long tail usable; ninety taxa are not.
    if (nrow(found) > 0) {
      from_file <- stats::setNames(found$shorthand,
                                   paste0(found$shorthand, " - ", found$species))
      common <- from_file[found$shorthand %in% catalog]
      rest <- from_file[!(found$shorthand %in% catalog)]
      choices <- if (length(common) > 0) {
        list(Common = common, `Other taxa in this file` = rest[order(names(rest))])
      } else {
        from_file[order(names(from_file))]
      }
      available <- unname(from_file)
    } else {
      choices <- catalog
      available <- catalog
    }

    selected <- isolate(input$species) %||% base_config$species$active
    if (!(selected %in% available)) selected <- available[1]

    updateSelectInput(session, "species", choices = choices, selected = selected)
  })

  # The file wins over the config. Both may know a `cfin`, and they can mean
  # different columns: the shipped catalog expects `cfin_*` stage columns, while
  # a formatted export calls the same animal CALANUS_FINMARCHICUS. Preferring the
  # catalog there would look up a prefix the loaded file does not have.
  species_entry <- reactive({
    req(input$species)
    threshold <- list(type = input$threshold_type, value = input$threshold_value)

    found <- file_species()
    row <- found[found$shorthand == input$species |
                   found$species == input$species, ]

    if (nrow(row) >= 1) {
      column <- row$species[1]
      entry <- if (identical(row$form[1], "stages")) {
        list(column_prefix = column)
      } else {
        list(abundance_column = column)
      }
      return(c(entry, list(threshold = threshold)))
    }

    known <- base_config$species$catalog[[input$species]]
    if (!is.null(known)) return(known)
    list(abundance_column = input$species, threshold = threshold)
  })

  species_prefix <- reactive({
    entry <- species_entry()
    entry$column_prefix %||% entry$abundance_column %||% input$species
  })

  # The uploaded file when there is one, otherwise whatever the launching config
  # pointed at - the mock database for a default session. Everything that reads
  # the station data goes through here rather than at base_config directly, so
  # an upload takes effect everywhere at once.
  # Browsing the machine the app is running on, which locally is this one. The
  # button fills the path box rather than being a second source of truth, so
  # everything downstream still reads one place.
  volumes <- c("Working directory" = getwd(),
               Home = path.expand("~"),
               shinyFiles::getVolumes()())
  shinyFiles::shinyFileChoose(input, "zoop_browse", roots = volumes,
                              filetypes = c("csv", "CSV"))
  observeEvent(input$zoop_browse, {
    chosen <- shinyFiles::parseFilePaths(volumes, input$zoop_browse)
    if (nrow(chosen) > 0) {
      updateTextInput(session, "zoop_path",
                      value = as.character(chosen$datapath[1]))
    }
  }, ignoreInit = TRUE)

  # A path rather than a browser upload. The station database is read where it
  # already is, which keeps a downloaded config usable afterwards - an uploaded
  # copy would live in a per-session temporary directory and be gone tomorrow.
  zoop_input <- reactive({
    typed <- trimws(input$zoop_path %||% "")
    if (!nzchar(typed)) return(base_config$paths$zoop_file)
    if (is_absolute(typed)) typed else file.path(getwd(), typed)
  })

  # A raw export is converted here rather than handed back with instructions.
  # It is the same call the documentation gives, run for you: the point of
  # pointing an app at a file is not to be told to go and run something first.
  # The result goes to a temporary file, so the original is never written to.
  formatted_zoop <- reactive({
    path <- zoop_input()
    if (!file.exists(path) || !is_raw_export(path)) {
      return(list(path = path, formatted = FALSE, error = NULL))
    }

    out <- file.path(tempdir(), paste0("taupatch_formatted_", basename(path)))
    result <- tryCatch({
      suppressWarnings(format_zoop_data(path, write_to = out))
      list(path = out, formatted = TRUE, error = NULL)
    }, error = function(e) {
      list(path = path, formatted = FALSE, error = conditionMessage(e))
    })
    result
  })

  zoop_path <- reactive(formatted_zoop()$path)

  zoop_source <- reactive({
    if (nzchar(trimws(input$zoop_path %||% ""))) "path" else "default"
  })

  stage_choices <- reactive({
    req(input$species)
    if (!file.exists(zoop_path())) return(character())
    found <- file_species()
    row <- found[found$shorthand == input$species |
                   found$species == input$species, ]
    # Only a taxon whose columns carry stages has any to offer.
    if (nrow(row) >= 1 && !identical(row$form[1], "stages")) return(character())
    tryCatch(available_stages(zoop_path(), species_prefix()),
             error = function(e) character())
  })

  # Reads the header only, never a data row, so a large database is checked in
  # the time it takes to open the file.
  data_header <- reactive({
    if (!file.exists(zoop_path())) return(NULL)
    tryCatch(
      names(readr::read_csv(zoop_path(), n_max = 0, show_col_types = FALSE,
                            progress = FALSE)),
      error = function(e) NULL
    )
  })

  # Says what the file is before a run is started, rather than letting a missing
  # column surface as a failure after the covariates have been downloaded.
  output$data_status <- renderUI({
    if (identical(zoop_source(), "default")) {
      return(helpText("Using the session default. Give the path to your own",
                      "station CSV to model it instead. It is read where it is",
                      "and never copied, so the config you download afterwards",
                      "points at the real file."))
    }
    if (identical(zoop_source(), "path") && !file.exists(zoop_path())) {
      return(div(class = "text-danger",
                 strong("No file at that path: "), tags$code(zoop_path())))
    }

    header <- data_header()
    if (is.null(header)) {
      return(div(class = "text-danger",
                 strong("Could not read that file as CSV.")))
    }

    prepared <- formatted_zoop()
    if (!is.null(prepared$error)) {
      return(tagList(
        div(strong(basename(zoop_input())), " - raw export"),
        div(class = "text-danger", style = "font-size: 12px; margin-top: 6px;",
            strong("Could not format it: "), prepared$error)
      ))
    }

    # The assembled config, not base_config. They differ in exactly the way that
    # matters here: current_config() drops the ECOMON filter when the loaded file
    # has no `dataset` column, and validating the shipped config instead reports
    # a missing column that the run itself would never have asked for.
    check <- tryCatch({
      validate_columns(current_config())
      NULL
    }, error = function(e) conditionMessage(e))

    resolvable <- names(base_config$species$catalog)[
      vapply(names(base_config$species$catalog), function(name) {
        entry <- base_config$species$catalog[[name]]
        prefix <- entry$column_prefix %||% name
        length(tryCatch(available_stages(zoop_path(), prefix),
                        error = function(e) character())) > 0
      }, logical(1))
    ]

    tagList(
      div(strong(basename(zoop_input())), " - ", length(header), " columns"),
      if (isTRUE(prepared$formatted)) {
        helpText(class = "text-success",
                 "Recognised as a raw export and formatted for this run.",
                 "Dates split, taxon columns renamed, abundances divided",
                 "through by the count their unit is per. The file on disk is",
                 "untouched.")
      },
      if (!is.null(check)) {
        div(class = "text-danger", style = "font-size: 12px; margin-top: 6px;",
            strong("Not usable yet: "), check)
      } else {
        div(class = "text-success", style = "font-size: 12px; margin-top: 6px;",
            "Required columns present.")
      },
      if (length(resolvable) > 0) {
        helpText("Species resolved in this file: ",
                 paste(resolvable, collapse = ", "))
      }
    )
  })

  # Remembered per type, because the two live on completely different scales -
  # a percentile is ~0.9 while an absolute threshold is in abundance units and
  # can be in the thousands. Carrying one over to the other would be nonsense.
  threshold_values <- reactiveValues(
    percentile = if (base_config$species$resolved$threshold$type == "percentile") {
      base_config$species$resolved$threshold$value
    } else 0.9,
    absolute = if (base_config$species$resolved$threshold$type == "absolute") {
      base_config$species$resolved$threshold$value
    } else 1000
  )

  observeEvent(input$threshold_value, {
    req(input$threshold_type)
    threshold_values[[input$threshold_type]] <- input$threshold_value
  })

  output$threshold_input <- renderUI({
    req(input$threshold_type)
    # isolate(): the remembered values update on every keystroke/drag, and
    # reading them reactively would re-render the control mid-interaction.
    remembered <- isolate(reactiveValuesToList(threshold_values))

    if (input$threshold_type == "percentile") {
      tagList(
        # 0 and 1 are excluded: either puts every station in a single class,
        # which leaves nothing for the model to separate.
        sliderInput("threshold_value", "Percentile", min = 0.01, max = 0.99,
                    value = remembered$percentile, step = 0.01),
        textOutput("threshold_note")
      )
    } else {
      tagList(
        numericInput("threshold_value", "Abundance threshold",
                     value = remembered$absolute, min = 0),
        textOutput("threshold_note")
      )
    }
  })

  output$threshold_note <- renderText({
    req(input$threshold_type, input$threshold_value)
    if (input$threshold_type == "percentile") {
      percentile <- input$threshold_value * 100
      paste0("Patches are the top ", format_percent(100 - percentile),
             "% of stations by abundance (", format_percent(percentile),
             "th percentile).")
    } else {
      paste0("Patches are stations with abundance at or above ",
             format(input$threshold_value, big.mark = ",", scientific = FALSE),
             " individuals/m2.")
    }
  })

  output$stage_picker <- renderUI({
    choices <- stage_choices()
    if (length(choices) == 0) {
      return(helpText("Stage list appears once the database is available.",
                      "All stages are summed until then."))
    }
    tagList(
      # character(0), not NULL: with NULL, selectize falls back to selecting the
      # first choice, which would silently narrow the run to one stage.
      selectInput("stages", "Life stages", choices = choices, multiple = TRUE,
                  selected = character(0)),
      helpText("Leave empty to sum every stage. Stage columns are read from the",
               "database, so the options differ by species.")
    )
  })

  # Rebuilds the config from the current form state. Kept as one function so the
  # Config tab always shows exactly what a run would use.
  current_config <- reactive({
    # threshold_value is rendered by renderUI, so it is briefly absent on the
    # first pass and when the threshold type changes.
    req(input$threshold_value)
    config <- base_config
    config$paths$zoop_file <- zoop_path()

    # The shipped config filters to ECOMON, which needs a `dataset` column. A
    # formatted export has none - the raw file does not carry one - so the
    # filter is dropped rather than failing validation on a column that was
    # never going to be there.
    if (!("dataset" %in% (data_header() %||% character()))) {
      config$columns$dataset_filter <- NULL
    }
    config$species$active <- input$species
    # A species found only in the data has no catalog entry yet, so one is put
    # there before the threshold is set on it.
    config$species$catalog[[input$species]] <- species_entry()
    config$species$catalog[[input$species]]$threshold <- list(
      type = input$threshold_type, value = input$threshold_value
    )
    # An empty multi-select means "all stages", which is what a NULL `stages`
    # already encodes, so it must not be stored as character(0).
    config$species$catalog[[input$species]]$stages <-
      if (length(input$stages) > 0) input$stages else NULL
    config$species$resolved <- taupatch:::resolve_species(config)

    # The boxes win when they hold a usable range. They are the precise input,
    # and an observer syncing them to the slider is a round-trip to the browser:
    # a run started between typing a year and the client echoing it back would
    # otherwise use the year that was there before.
    config$dates$years <- typed_years(input$year_from, input$year_to,
                                      input$years)
    config$dates$months <- input$months

    if (isTRUE(input$projection_same)) {
      config$projection$years <- input$years
      config$projection$months <- input$months
    } else {
      config$projection$years <- input$proj_years %||% input$years
      config$projection$months <- input$proj_months %||% input$months
    }

    config$study_area$bbox <- list(xmin = input$xmin, xmax = input$xmax,
                                    ymin = input$ymin, ymax = input$ymax)
    config$model$type <- input$model_type
    config$model$bs <- if (identical(input$model_type, "gam")) input$gam_bs
    config$model$method <- if (identical(input$model_type, "gam")) input$gam_method
    config$model$family <- if (identical(input$model_type, "gam")) input$gam_family
    config$model$select_features <- isTRUE(input$gam_select) &&
      identical(input$model_type, "gam")

    # Only a GAM takes one, and only a column the run will have. Cleared
    # otherwise, so switching model type does not leave a stale term behind
    # that predictor_names() would then quietly drop.
    offset <- input$offset %||% ""
    config$model$offset <- if (identical(input$model_type, "gam") &&
                               nzchar(offset)) {
      offset
    }
    # Only set alongside an offset. On its own it would be partial-matched by
    # any later `$offset` lookup and read as the offset column itself.
    config$model$offset_transform <- if (!is.null(config$model[["offset"]])) {
      input$offset_transform %||% "none"
    }
    # An older config's `engine` would otherwise still be there and be read as
    # the type by anything reading the downloaded file.
    config$model$engine <- NULL
    config$model$trees <- input$trees %||% base_config$model$trees
    config$model$cv_folds <- input$cv_folds
    # A derived covariate needs its inputs downloaded even when nobody wants
    # them modelled, so they are added to the fetch and named in `exclude`,
    # which keeps them out of the predictors.
    ingredients <- derivoce_required_inputs(input$derived %||% character(),
                                            input$covariates %||% character(),
                                            input$bathymetry %||% character())
    config$covariates$selected <- union(input$covariates %||% character(),
                                        ingredients)
    config$covariates$exclude <- ingredients
    config$covariates$bathymetry <- input$bathymetry %||% character()
    config$covariates$climate <- input$climate %||% character()

    # Derived covariates are named by the column they produce; the config wants
    # the step that produces it. Rebuilt from the current selection rather than
    # remembered, so a derived covariate whose source was deselected disappears
    # with it instead of failing validation.
    config$covariates$derivoce <- derivoce_steps_for(
      input$derived, config$covariates$selected, config$covariates$bathymetry
    )

    # The sidebar owns the transform block outright, so a stale log_transform
    # from the config the app opened on cannot survive alongside it and be
    # merged back in by covariate_transform_spec().
    config$covariates$log_transform <- character()

    # Gathered from the per-covariate controls and inverted into the config's
    # shape, which groups covariates under a transform rather than the other way
    # round. Only covariates the run will actually have: a control left behind by
    # a covariate since deselected would name something the config does not
    # fetch, and fail validation.
    chosen <- list()
    for (v in transformable()) {
      picked <- input[[paste0("transform_", v)]]
      if (is.null(picked) || identical(picked, "none")) next
      chosen[[picked]] <- c(chosen[[picked]], v)
    }
    config$covariates$transform <- chosen
    # Always Copernicus from the app. The shipped config says `mock` so the
    # package can be tried without credentials, and inheriting that here meant
    # real stations were being modelled against invented covariates with nothing
    # saying so. A synthetic run is a headless one.
    config$covariates$source <- "copernicus"
    config$covariates$normalize <- isTRUE(input$normalize)

    # Fetched in parallel by default here, which a headless run leaves to the
    # config. Someone sitting in front of a progress bar is waiting on the
    # Copernicus API, and four requests at once is the difference between a
    # coffee and an afternoon. Capped low: the bottleneck is their end.
    config$covariates$n_workers <- config$covariates$n_workers %||%
      min(4L, max(1L, parallel::detectCores() - 1L))
    config
  })

  output$config_yaml <- renderText({
    config <- current_config()
    config$species$resolved <- NULL
    yaml::as.yaml(config[c("paths", "columns", "species", "dates",
                            "study_area", "covariates", "model", "projection")])
  })

  output$model_type_note <- renderUI({
    req(input$model_type)
    helpText(model_type_catalog[[input$model_type]]$description)
  })

  output$download_config <- downloadHandler(
    filename = function() {
      paste0(current_config()$species$active, "_",
             format(Sys.Date(), "%Y%m%d"), ".yaml")
    },
    content = function(file) save_config(current_config(), file)
  )

  observeEvent(input$show_dictionary, {
    updateTabsetPanel(session, "main_tabs", selected = "Covariate dictionary")
  }, ignoreInit = TRUE)

  observeEvent(input$run, {
    config <- current_config()

    withProgress(message = "Running taupatch", value = 0, {
      messages <- character()
      # Checked before anything is downloaded. The failure is otherwise a wall
      # of parallel-node errors arriving after the first request times out.
      if (identical(config$covariates$source, "copernicus") &&
          !nzchar(taupatch::copernicus_client())) {
        run_log(paste(
          "ERROR: the Copernicus Marine client was not found.",
          "\n\nInstall it:  pip install copernicusmarine",
          "\nSign in once: copernicusmarine login",
          "\n\nIf it is installed but R cannot see it - which happens when the",
          "app is launched from RStudio rather than a terminal, since that does",
          "not inherit your shell's PATH - start the app after setting:",
          "\n  options(datamatch.copernicusmarine = \"/full/path/to/copernicusmarine\")"
        ))
        run_result(NULL)
        showNotification("Copernicus client not found - see the Log tab.",
                         type = "error", duration = NULL)
        return()
      }

      result <- tryCatch(
        withCallingHandlers({
          incProgress(0.1, detail = "loading data")
          if (config$covariates$source == "mock" && !file.exists(config$paths$zoop_file)) {
            generate_mock_zoop_data(config)
          }
          run_taupatch(config)
        }, message = function(m) {
          text <- sub("\n$", "", conditionMessage(m))
          messages <<- c(messages, text)

          # The named stages move the bar; everything else is detail within the
          # stage it belongs to, and shown as such. Nudging the bar on every
          # message instead would have it racing through the quick ones and
          # stalling through the twenty-minute download.
          stage <- taupatch:::match_pipeline_stage(text)
          if (!is.null(stage)) {
            setProgress(value = stage$at,
                        message = paste0(round(stage$at * 100), "% - ",
                                         stage$label),
                        detail = "")
          } else if (nzchar(trimws(text))) {
            setProgress(detail = trimws(text))
          }
          invokeRestart("muffleMessage")
        }),
        error = function(e) {
          messages <<- c(messages, paste("ERROR:", conditionMessage(e)))
          NULL
        }
      )
      run_log(paste(messages, collapse = "\n"))
      run_result(result)
    })

    if (is.null(run_result())) {
      showNotification("Run failed - see the Log tab.", type = "error", duration = NULL)
    } else {
      showNotification("Run complete.", type = "message")
    }
  })

  output$log <- renderText(run_log())

  # Loaded from whatever the sidebar currently points at, so the tab describes
  # the data a run would use rather than the data the last run happened to use.
  zoop_data <- reactive({
    config <- current_config()
    if (!file.exists(config$paths$zoop_file)) return(NULL)
    tryCatch(load_zoop_data(config), error = function(e) conditionMessage(e))
  })

  output$zoop_status <- renderUI({
    dat <- zoop_data()
    if (is.null(dat)) {
      return(helpText("No data file. Give a path in the sidebar."))
    }
    if (is.character(dat)) {
      return(div(class = "text-danger", strong("Could not load: "), dat))
    }
    helpText(nrow(dat), " stations of ", strong(current_config()$species$active),
             " after the date, area and species filters in the sidebar.")
  })

  # Everything below wants a loaded frame, so the guard is written once.
  loaded_zoop <- reactive({
    dat <- zoop_data()
    validate(need(!is.null(dat) && !is.character(dat),
                  "Load a zooplankton file to see this."))
    dat
  })

  output$zoop_summary <- renderTable({
    summary <- station_summary(loaded_zoop())
    stats::setNames(summary, c("", ""))
  })

  output$zoop_map <- renderPlot(plot_station_map(loaded_zoop()))

  output$zoop_series <- renderPlot(plot_station_series(loaded_zoop()))

  output$zoop_distribution <- renderPlot({
    dat <- loaded_zoop()
    config <- current_config()
    threshold <- tryCatch(
      attr(label_patch(dat, config), "threshold"), error = function(e) NA_real_
    )

    p <- ggplot2::ggplot(dat, ggplot2::aes(x = .data$abundance)) +
      ggplot2::geom_histogram(bins = 40, fill = "#2c7fb8", alpha = 0.85) +
      ggplot2::scale_x_continuous(trans = "log1p") +
      ggplot2::labs(x = "Abundance (log scale)", y = "Stations") +
      ggplot2::theme_minimal()

    if (is.finite(threshold)) {
      p <- p +
        ggplot2::geom_vline(xintercept = threshold, linetype = "dashed",
                            colour = "#c0392b", linewidth = 0.7) +
        ggplot2::annotate("text", x = threshold, y = Inf, hjust = -0.05,
                          vjust = 1.6, colour = "#c0392b", size = 3.4,
                          label = paste0("patch threshold ", signif(threshold, 4)))
    }
    p
  })

  # One clickable row per covariate; clicking opens a modal with the full
  # definition rather than crowding the table with prose.
  output$covariate_reference <- renderUI({
    info <- covariate_info(include_derived = TRUE)
    rows <- lapply(seq_len(nrow(info)), function(i) {
      fluidRow(
        style = "padding: 6px 0; border-bottom: 1px solid #eee;",
        column(2, actionLink(paste0("covar_info_", i), strong(info$name[i]))),
        column(4, info$label[i]),
        column(2, tags$code(info$units[i])),
        column(2, tags$small(info$spatial[i])),
        column(2, tags$small(info$temporal[i]))
      )
    })
    tagList(
      fluidRow(
        style = "padding-bottom: 6px; border-bottom: 2px solid #ccc; font-weight: bold;",
        column(2, "Name"), column(4, "Long name"),
        column(2, "Units"), column(2, "Grid"), column(2, "Time step")
      ),
      rows,
      br(),
      helpText("Grid spacing is the source product's own. Selecting covariates",
               "from products of different resolution means one grid has to be",
               "reconciled onto the other, and which is finer is not always the",
               "obvious one: satellite chlorophyll at 4 km is finer than the",
               "0.083 degree physics, while the model chlorophyll at 0.25",
               "degrees is far coarser than both.")
    )
  })

  observe({
    info <- covariate_info(include_derived = TRUE)
    lapply(seq_len(nrow(info)), function(i) {
      observeEvent(input[[paste0("covar_info_", i)]], {
        showModal(modalDialog(
          title = paste0(info$name[i], " - ", info$label[i]),
          p(info$description[i]),
          tags$dl(
            tags$dt("Units"), tags$dd(tags$code(info$units[i])),
            tags$dt("Spatial resolution"), tags$dd(info$spatial[i]),
            tags$dt("Temporal resolution"), tags$dd(info$temporal[i]),
            tags$dt("Copernicus variable"), tags$dd(tags$code(info$variable[i])),
            tags$dt("Dataset"), tags$dd(tags$code(info$dataset[i]))
          ),
          easyClose = TRUE, footer = modalButton("Close")
        ))
      }, ignoreInit = TRUE)
    })
  })

  output$metrics <- renderTable({
    req(run_result())
    evaluation <- run_result()$model$evaluation
    data.frame(
      Metric = evaluation$metric,
      # A blank cutoff reads better than NA for metrics that genuinely have
      # none, and keeps the eye on the two that do.
      Cutoff = ifelse(is.na(evaluation$threshold), "",
                      format(round(evaluation$threshold, 3), nsmall = 3)),
      Value = round(evaluation$value, 3),
      `Std. err` = ifelse(is.na(evaluation$std_err), "",
                          format(round(evaluation$std_err, 4), nsmall = 4)),
      Note = evaluation$note,
      check.names = FALSE
    )
  })

  output$importance <- renderPlot({
    req(run_result())
    plot_importance(run_result()$model$importance)
  })

  output$threshold <- renderText({
    req(run_result())
    paste0("Abundance threshold used: ", signif(run_result()$model$threshold, 6))
  })

  # Partial effects need to re-predict, so they are computed once per run
  # rather than on every redraw of the tab.
  run_effects <- reactive({
    req(run_result())
    model <- run_result()$model
    taupatch:::try_diagnostic(
      partial_effects(model$workflow, model$model_data, model$predictors),
      "partial effects"
    )
  })

  # A GAM has its own partial effects, and they are better than the generic
  # ones: read out of the fitted model rather than reconstructed by prediction,
  # so they carry the uncertainty a partial dependence curve cannot.
  use_fancygam <- reactive({
    identical(run_result()$model$type, "gam") &&
      requireNamespace("fancygam", quietly = TRUE)
  })

  output$partial_effects_note <- renderUI({
    req(run_result())
    if (isTRUE(use_fancygam())) {
      return(helpText("The model's own smooths, with standard error bands and a",
                      "rug showing where the data is, drawn by fancygam. The x",
                      "axes are in standard deviations because the model was",
                      "fitted on the centred and scaled predictors - turn off",
                      "'Centre and scale' to read them in the covariate's own",
                      "units."))
    }
    helpText("What each predictor does to patch probability, with the others",
             "held at the values they actually take. Importance says a predictor",
             "matters; this says which way. Computed the same way for every",
             "model type, so the curves can be compared across them.")
  })

  output$partial_effects <- renderPlot({
    req(run_result())
    if (isTRUE(use_fancygam())) {
      return(suppressMessages(plot_gam_smooths(run_result()$model)))
    }
    effects <- run_effects()
    validate(need(!is.null(effects) && nrow(effects) > 0,
                  "Partial effects are unavailable for this run."))
    plot_partial_effects(effects)
  })

  # The one thing the chosen model can say that the others cannot.
  output$model_specific <- renderUI({
    req(run_result())
    model <- run_result()$model

    if (identical(model$type, "glm")) {
      return(tagList(
        h4("Coefficients"),
        helpText("Log-odds per standard deviation, with 95% intervals. An",
                 "interval crossing zero is a predictor the model cannot sign."),
        plotOutput("glm_coefficients", height = "320px")
      ))
    }
    if (identical(model$type, "gam")) {
      # The smooths themselves are the partial effects panel above when
      # fancygam is present, so they are not repeated here.
      return(tagList(
        h4("Smooth terms"),
        helpText("Effective degrees of freedom per smooth. An edf of 1 means",
                 "the smooth collapsed to a straight line, so the flexibility",
                 "bought nothing there; larger values mean a real bend."),
        tableOutput("gam_terms"),
        h4("Model summary"),
        helpText("mgcv's own summary of the fitted model: the parametric terms,",
                 "the approximate significance of each smooth, deviance",
                 "explained, and the smoothing parameter selection score."),
        verbatimTextOutput("gam_summary")
      ))
    }
    NULL
  })

  output$glm_coefficients <- renderPlot({
    req(run_result())
    plot_glm_coefficients(glm_coefficients(run_result()$model$workflow))
  })

  output$gam_summary <- renderPrint({
    req(run_result())
    summary(model_engine_fit(run_result()$model))
  })

  output$gam_terms <- renderTable({
    req(run_result())
    terms <- gam_smooth_terms(run_result()$model$workflow)
    data.frame(Term = terms$term, edf = round(terms$edf, 2),
               `p value` = format.pval(terms$p_value, digits = 3),
               check.names = FALSE)
  })

  output$map_controls <- renderUI({
    # An empty Maps tab is indistinguishable from a broken one, so say which it is.
    if (is.null(run_result())) {
      return(helpText("Run a model first - maps appear here once it finishes."))
    }
    projections <- run_result()$projections
    if (is.null(projections) || nrow(projections) == 0) {
      return(helpText("This run produced no projections."))
    }
    downloadable <- sum(!is.na(projections$geotiff))
    coverage <- if (all(c("n_cells", "n_grid") %in% names(projections))) {
      worst <- projections[which.min(projections$n_cells / projections$n_grid), ]
      if (worst$n_cells < worst$n_grid) {
        helpText(
          class = if (worst$n_cells < 0.8 * worst$n_grid) "text-warning" else NULL,
          sprintf("Grid: %s degrees (~%s km). Thinnest month maps %d of %d cells (%d%%).",
                  signif(worst$resolution, 3), round(worst$resolution * 111),
                  worst$n_cells, worst$n_grid,
                  round(100 * worst$n_cells / worst$n_grid)),
          if (worst$n_cells < 0.8 * worst$n_grid) {
            paste("A cell is dropped where any predictor is missing, which is",
                  "what makes a map look patchy. Gaps in a satellite covariate",
                  "are the usual cause - fill them with a fill_gaps step - and a",
                  "gradient or front losing the study-area border is the other.")
          }
        )
      }
    }

    tagList(
      coverage,
      fluidRow(
        column(5, selectInput("projection", "Month",
                              choices = stats::setNames(
                                seq_len(nrow(projections)),
                                paste(month.name[projections$month], projections$year)
                              ))),
        column(7, br(),
               downloadButton("download_projections",
                              paste0("Download ", downloadable, " GeoTIFFs (.zip)")),
               downloadButton("download_suitability",
                              "Download probabilities (.csv)"),
               downloadButton("download_stack",
                              "Download raster stack (.grd)"))
      )
    )
  })

  # Ships the whole projection stack as one zip: a folder of <year>-<month>.tiff
  # files, so they sort chronologically and carry their date in the name.
  output$download_projections <- downloadHandler(
    filename = function() {
      paste0(run_result()$config$species$resolved$name, "_projections.zip")
    },
    content = function(file) {
      projections <- run_result()$projections
      projections <- projections[!is.na(projections$geotiff), ]
      validate(need(nrow(projections) > 0, "This run wrote no GeoTIFFs."))

      folder <- paste0(run_result()$config$species$resolved$name, "_projections")
      staging <- file.path(tempdir(), "taupatch_download")
      unlink(staging, recursive = TRUE)
      dir.create(file.path(staging, folder), recursive = TRUE, showWarnings = FALSE)

      for (i in seq_len(nrow(projections))) {
        file.copy(projections$geotiff[i],
                  file.path(staging, folder,
                            sprintf("%d-%02d.tiff", projections$year[i],
                                    projections$month[i])))
      }

      # zip() stores paths as given, so it has to run from the staging directory
      # for the archive to contain `<folder>/...` rather than the full temp path.
      old <- setwd(staging)
      on.exit(setwd(old), add = TRUE)
      utils::zip(file, folder, flags = "-r9Xq")
    },
    contentType = "application/zip"
  )

  # What can be derived depends on what was fetched: a gradient of SST needs
  # SST, and current speed needs both components. Recomputed as the selection
  # changes, dropping anything that is no longer buildable.
  derived_candidates <- reactive({
    # fetchable defaults to the whole catalog, so the FSLE is offered whether or
    # not the velocity components were picked as predictors. Choosing it adds
    # them to the fetch and keeps them out of the model.
    derivoce_choices(input$covariates %||% character(),
                     input$bathymetry %||% character())
  })

  observe({
    candidates <- derived_candidates()
    choices <- lapply(split(candidates, vapply(candidates, function(x) x$group,
                                                character(1))),
                      function(group) {
                        stats::setNames(
                          vapply(group, function(x) x$id, character(1)),
                          vapply(group, function(x) {
                            paste0(x$label, if (x$expensive) "  (slow)" else "")
                          }, character(1))
                        )
                      })

    available <- vapply(candidates, function(x) x$id, character(1))
    updateSelectInput(session, "derived", choices = choices,
                      selected = intersect(isolate(input$derived), available))
  })

  output$derived_note <- renderUI({
    chosen <- input$derived
    if (length(chosen) == 0) {
      return(helpText("Covariates computed from the grid rather than downloaded",
                      "- gradients, fronts, lags, accumulations. They are",
                      "computed before stations are matched, because a gradient",
                      "is a property of the field. Options depend on what is",
                      "selected above."))
    }
    slow <- Filter(function(x) x$id %in% chosen && x$expensive, derived_candidates())
    lagged <- grepl("_lag|_int|_tgrad", chosen)
    ingredients <- derivoce_required_inputs(chosen, input$covariates %||% character(),
                                            input$bathymetry %||% character())

    tagList(
      helpText(length(chosen), " derived covariate(s) selected."),
      if (length(ingredients) > 0) {
        helpText(paste(ingredients, collapse = ", "),
                 if (length(ingredients) == 1) " will be" else " will be",
                 " downloaded to compute these, and kept out of the model.")
      },
      if (any(lagged)) {
        helpText(class = "text-warning",
                 "Lags, accumulations and rates of change are undefined in the",
                 "first month of the record, so those stations drop out and that",
                 "month is not mapped.")
      },
      if (length(slow) > 0) {
        helpText(class = "text-warning",
                 "The distance covariates run a distance transform per month.",
                 "Expect minutes rather than seconds on a full Copernicus grid.")
      }
    )
  })

  # An offset has to be a column the data actually carries, and it is removed
  # from the predictors when used, so it is offered from the same pool.
  observe({
    derived <- vapply(derived_candidates(), function(x) x$id, character(1))
    available <- c(input$covariates, input$bathymetry,
                   intersect(derived, input$derived %||% character()))

    updateSelectInput(session, "offset",
                      choices = c("none" = "", stats::setNames(available, available)),
                      selected = if (isolate(input$offset) %in% available) {
                        isolate(input$offset)
                      } else "")
  })

  output$climate_note <- renderUI({
    if (length(input$climate) == 0) {
      return(helpText("Basin-scale modes: one value per month for the whole",
                      "study area, downloaded from NOAA."))
    }
    helpText(class = "text-warning",
             "An index has no spatial structure. It shifts every cell of a",
             "month's map by the same amount, so it can say which years and",
             "seasons were unusual but nothing about where a patch is.")
  })

  # Every predictor a run will have, which is what a transform may name.
  transformable <- reactive({
    derived <- vapply(derived_candidates(), function(x) x$id, character(1))
    derived <- intersect(derived, input$derived %||% character())
    ingredients <- derivoce_required_inputs(input$derived %||% character(),
                                            input$covariates %||% character(),
                                            input$bathymetry %||% character())
    # Ingredients are fetched but not modelled, so transforming one would be
    # transforming something the model never sees.
    setdiff(c(input$covariates, input$bathymetry, derived, input$climate),
            ingredients)
  })

  # One row per covariate rather than one transform applied to a set. Different
  # covariates want different treatment - chlorophyll a fourth root, depth a
  # log, a signed gradient Yeo-Johnson - and the config has always allowed that;
  # only the control did not.
  output$transform_rows <- renderUI({
    covariates <- transformable()
    if (length(covariates) == 0) {
      return(helpText("Select covariates first."))
    }

    existing <- taupatch:::covariate_transform_spec(base_config)
    current <- stats::setNames(rep("none", length(covariates)), covariates)
    for (name in names(existing)) {
      for (v in intersect(existing[[name]], covariates)) current[[v]] <- name
    }

    rows <- lapply(covariates, function(v) {
      fluidRow(
        style = "margin-bottom: 2px;",
        column(5, style = "padding-right: 4px; padding-top: 6px;",
               tags$small(v)),
        column(7, style = "padding-left: 4px;",
               selectInput(paste0("transform_", v), NULL,
                           choices = c("none", names(transform_catalog)),
                           selected = isolate(input[[paste0("transform_", v)]]) %||%
                             current[[v]],
                           width = "100%"))
      )
    })
    tagList(rows,
            helpText("One transform each. taupatch::covariate_transforms()",
                     "describes them; the log and root family folds a negative",
                     "sign, so a gradient wants yeojohnson."))
  })

  # Names what is currently selected, so the chosen predictor set is legible
  # without opening the dropdown, and flags the empty case - a run with no
  # covariates has nothing to model on and fails in config validation.
  output$covariate_label <- renderUI({
    selected <- input$covariates
    if (length(selected) == 0) {
      return(tags$label("Copernicus - none selected", class = "control-label",
                        style = "color: #c0392b;"))
    }
    tags$label(
      sprintf("Copernicus - %d selected: %s", length(selected),
              paste(selected, collapse = ", ")),
      class = "control-label"
    )
  })

  diagnostic_predictions <- reactive({
    req(run_result())
    run_result()$model$predictions
  })

  output$diagnostic_note <- renderUI({
    if (is.null(run_result())) {
      return(helpText("Run a model first - diagnostics appear here once it finishes."))
    }
    cutoff <- run_result()$model$classification_threshold
    if (is.na(cutoff)) return(NULL)
    # Surfaced because the metrics table reports sens/spec at 0.5, which for a
    # tenth-prevalence problem understates what the model can do.
    helpText(sprintf(
      "TSS is maximised at a probability cutoff of %.3f. The Results tab's
       sensitivity and specificity are at the default 0.5.", cutoff))
  })

  output$roc_plot <- renderPlot(plot_roc_curve(diagnostic_predictions()))
  output$pr_plot <- renderPlot(plot_pr_curve(diagnostic_predictions()))
  output$calibration_plot <- renderPlot(plot_calibration(diagnostic_predictions()))
  output$threshold_plot <- renderPlot(plot_threshold_performance(diagnostic_predictions()))

  output$heatmap_controls <- renderUI({
    if (is.null(run_result())) {
      return(helpText("Run a model first - covariate trends appear here once it finishes."))
    }
    covariates <- unique(run_result()$covariate_means$covariate)
    selectInput("heatmap_covariate", "Covariate", choices = covariates,
                width = "320px")
  })

  output$covariate_heatmap <- renderPlot({
    req(run_result(), input$heatmap_covariate)
    plot_covariate_heatmap(run_result()$covariate_means, input$heatmap_covariate)
  })

  # A heatmap cell is a year and a month, and the value in it is the thing
  # being read. ggplot has no tooltip, so the hover position is mapped back
  # through the same factor levels the plot was built from.
  output$heatmap_value <- renderUI({
    req(run_result(), input$heatmap_covariate)
    hover <- input$heatmap_hover
    if (is.null(hover)) {
      return(helpText("Hover a cell for its value."))
    }

    means <- run_result()$covariate_means
    subset <- means[means$covariate == input$heatmap_covariate, ]
    years <- sort(unique(subset$year))

    # Only the months present are drawn. A discrete scale positions the levels
    # it uses at 1..n and skips the rest, so indexing into all twelve put the
    # hover three rows out on a summer-only record and read December for August.
    months <- rev(month.abb)[rev(month.abb) %in% month.abb[unique(subset$month)]]

    # Discrete axes are drawn at 1..n, so the nearest integer is the cell.
    xi <- round(hover$x)
    yi <- round(hover$y)
    if (is.na(xi) || is.na(yi) || xi < 1 || xi > length(years) ||
        yi < 1 || yi > length(months)) {
      return(helpText("Hover a cell for its value."))
    }

    month_number <- match(months[yi], month.abb)
    cell <- subset[subset$year == years[xi] & subset$month == month_number, ]
    if (nrow(cell) == 0) {
      return(helpText(months[yi], " ", years[xi], ": no data"))
    }

    units <- taupatch:::covariate_units(input$heatmap_covariate)
    div(
      style = "font-size: 14px; padding: 4px 0;",
      strong(paste0(months[yi], " ", years[xi], ": ")),
      signif(cell$mean[1], 4),
      if (nzchar(units)) tags$span(style = "color: #666;", " ", units)
    )
  })

  output$covariate_map_controls <- renderUI({
    result <- run_result()
    if (is.null(result) || is.null(result$covariates)) {
      return(helpText("Run a model first - covariate maps appear here once it",
                      "finishes."))
    }
    steps <- unique(sf::st_drop_geometry(result$covariates)[c("YEAR", "MONTH")])
    steps <- steps[order(steps$YEAR, steps$MONTH), ]

    fluidRow(
      column(5, selectInput("map_covariate", "Covariate",
                            choices = datamatch::covariate_columns(result$covariates))),
      column(5, selectInput("map_step", "Month",
                            choices = stats::setNames(
                              seq_len(nrow(steps)),
                              paste(month.name[steps$MONTH], steps$YEAR)
                            )))
    )
  })

  output$covariate_map <- renderPlot({
    result <- run_result()
    validate(need(!is.null(result) && !is.null(result$covariates),
                  "Run a model to see covariate maps."))
    req(input$map_covariate, input$map_step)

    steps <- unique(sf::st_drop_geometry(result$covariates)[c("YEAR", "MONTH")])
    steps <- steps[order(steps$YEAR, steps$MONTH), ]
    step <- steps[as.integer(input$map_step), ]

    plot_covariate_map(result$covariates, input$map_covariate,
                       step$YEAR, step$MONTH)
  })

  output$covariate_seasonal <- renderPlot({
    req(run_result(), input$heatmap_covariate)
    plot_covariate_seasonal(run_result()$covariate_means, input$heatmap_covariate)
  })

  output$covariate_annual <- renderPlot({
    req(run_result(), input$heatmap_covariate)
    plot_covariate_annual(run_result()$covariate_means, input$heatmap_covariate)
  })

  # Every month in one long table: species, year, month, longitude, latitude,
  # probability. The GeoTIFFs carry their coordinates for a GIS; this is the
  # form for everything else, and it is read off disk rather than rebuilt so a
  # large run is not held in memory to be downloaded.
  output$download_suitability <- downloadHandler(
    filename = function() {
      paste0(run_result()$config$species$active, "_suitability_",
             format(Sys.Date(), "%Y%m%d"), ".csv")
    },
    content = function(file) {
      table <- attr(run_result()$projections, "table")
      if (is.null(table) || !file.exists(table)) {
        # projection.write_csv was off, so it is rebuilt from the rasters
        # rather than refusing.
        projections <- run_result()$projections
        rows <- lapply(which(!is.na(projections$geotiff)), function(i) {
          rast <- terra::rast(projections$geotiff[i])
          frame <- as.data.frame(rast, xy = TRUE)
          names(frame) <- c("lon", "lat", "suitability")
          cbind(species = run_result()$config$species$active,
                year = projections$year[i], month = projections$month[i],
                frame)
        })
        readr::write_csv(dplyr::bind_rows(rows), file)
        return(invisible(NULL))
      }
      file.copy(table, file, overwrite = TRUE)
    }
  )

  # Zipped, because a .grd is two files - the header and the .gri holding the
  # data - and either one alone is unreadable.
  output$download_stack <- downloadHandler(
    filename = function() {
      paste0(run_result()$config$species$active, "_suitability_",
             format(Sys.Date(), "%Y%m%d"), "_grd.zip")
    },
    contentType = "application/zip",
    content = function(file) {
      folder <- paste0(run_result()$config$species$resolved$name, "_stack")
      staging <- file.path(tempdir(), "taupatch_stack")
      unlink(staging, recursive = TRUE)
      dir.create(file.path(staging, folder), recursive = TRUE,
                 showWarnings = FALSE)

      # Built on demand rather than depending on the run having been configured
      # to write one.
      write_suitability_stack(run_result()$projections,
                              file.path(staging, folder, "suitability.grd"))

      # Same reason as the GeoTIFF download: zip() stores paths as given, so it
      # runs from the staging directory to avoid burying the archive under the
      # full temp path.
      old <- setwd(staging)
      on.exit(setwd(old), add = TRUE)
      utils::zip(file, folder, flags = "-r9Xq")
    }
  )

  output$map <- leaflet::renderLeaflet({
    req(run_result(), input$projection)
    projections <- run_result()$projections
    projection_map(projections$geotiff[as.integer(input$projection)])
  })
}

shinyApp(ui, server)
