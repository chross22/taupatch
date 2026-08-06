library(shiny)
library(taupatch)

`%||%` <- function(x, y) if (is.null(x)) y else x

# Drops the trailing ".0" that a 0.01-step slider otherwise produces, so the
# note reads "top 15%" rather than "top 15.0%".
format_percent <- function(x) format(round(x, 1), trim = TRUE, drop0trailing = TRUE)

# Config values the launcher passes through, so the app opens on a sensible
# starting config rather than an empty form.
base_config <- getOption("taupatch.app_config")

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

ui <- fluidPage(
  tags$head(tags$style(HTML("
    .tp-header { display: flex; align-items: center; gap: 20px; flex-wrap: wrap;
                 padding: 12px 0 16px; border-bottom: 1px solid #e3e3e3;
                 margin-bottom: 18px; }
    .tp-header-figure { margin: 0; flex: 0 0 auto; }
    /* Cropped to a banner strip and biased upward, so the copepod's body fills
       the frame rather than the empty background below it. */
    .tp-header-photo { height: 78px; width: 220px; object-fit: cover;
                       object-position: 50% 40%; border-radius: 4px;
                       display: block; }
    .tp-header-credit { font-size: 10px; color: #888; margin-top: 3px;
                        line-height: 1.3; max-width: 220px; }
    .tp-header-title { margin: 0; font-size: 26px; }
    .tp-header-sub { color: #666; margin: 4px 0 0; font-size: 14px; }
    @media (max-width: 700px) { .tp-header-photo { width: 100%; } }
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
      h4("Species"),
      selectInput("species", "Species", choices = names(base_config$species$catalog),
                  selected = base_config$species$active),
      uiOutput("stage_picker"),
      selectInput("threshold_type", "Threshold type",
                  choices = c("percentile", "absolute"),
                  selected = base_config$species$resolved$threshold$type),
      uiOutput("threshold_input"),

      hr(),
      h4("Training window"),
      helpText("Which observations the model is fitted on."),
      sliderInput("years", "Years",
                  min = 1977, max = as.integer(format(Sys.Date(), "%Y")),
                  value = base_config$dates$years, step = 1, sep = ""),
      sliderInput("months", "Months", min = 1, max = 12,
                  value = base_config$dates$months, step = 1),

      hr(),
      h4("Projection window"),
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
      ),

      hr(),
      h4("Study area"),
      fluidRow(
        column(6, numericInput("xmin", "West", base_config$study_area$bbox$xmin)),
        column(6, numericInput("xmax", "East", base_config$study_area$bbox$xmax))
      ),
      fluidRow(
        column(6, numericInput("ymin", "South", base_config$study_area$bbox$ymin)),
        column(6, numericInput("ymax", "North", base_config$study_area$bbox$ymax))
      ),

      hr(),
      h4("Model"),
      numericInput("trees", "Trees", value = base_config$model$trees, min = 1),
      numericInput("cv_folds", "CV folds", value = base_config$model$cv_folds, min = 2),

      hr(),
      h4("Covariates"),
      uiOutput("covariate_label"),
      selectInput("covariates", NULL, multiple = TRUE,
                  choices = covariate_choices,
                  selected = base_config$covariates$selected %||% c("SST", "SSS")),
      # character(0), not NULL: with NULL, selectize falls back to selecting the
      # first choice, which would silently opt every run into a NOAA download.
      selectInput("bathymetry", "Seafloor (static)", multiple = TRUE,
                  choices = bathymetry_choices,
                  selected = base_config$covariates$bathymetry %||% character(0)),
      # Choices are narrowed to what is actually selected above, by the observer
      # in the server. Offering unselected covariates here would let a config
      # name a log-transform for something the run never fetches, which config
      # validation rejects.
      selectInput("log_transform", "Log-transform", multiple = TRUE,
                  choices = character(0),
                  selected = base_config$covariates$log_transform %||% character(0)),
      helpText("Seafloor covariates are downloaded once from NOAA ETOPO and do",
               "not vary in time. Day of year is always included, and is what",
               "makes one model produce month-specific maps. See the Covariates",
               "tab for units and definitions."),

      hr(),
      actionButton("run", "Run model", class = "btn-primary", width = "100%")
    ),

    mainPanel(
      width = 9,
      tabsetPanel(
        tabPanel("Config", br(), verbatimTextOutput("config_yaml")),
        tabPanel("Covariates", br(),
                 p("Click a covariate for its full definition, units, and the",
                   "Copernicus variable and dataset it comes from."),
                 uiOutput("covariate_reference")),
        tabPanel("Results", br(),
                 h4("Cross-validated performance"), tableOutput("metrics"),
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
                 )),
        tabPanel("Maps", br(),
                 uiOutput("map_controls"),
                 leaflet::leafletOutput("map", height = "600px")),
        tabPanel("Covariate trends", br(),
                 p("Study-area mean of each covariate by month and year.",
                   "The seasonal cycle reads down a column, interannual change",
                   "across a row, and gaps in the record show up as blank cells."),
                 uiOutput("heatmap_controls"),
                 plotOutput("covariate_heatmap", height = "480px")),
        tabPanel("Log", br(), verbatimTextOutput("log"))
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
  species_prefix <- reactive({
    entry <- base_config$species$catalog[[input$species]]
    entry$column_prefix %||% input$species
  })

  stage_choices <- reactive({
    req(input$species)
    if (!file.exists(base_config$paths$zoop_file)) return(character())
    tryCatch(available_stages(base_config$paths$zoop_file, species_prefix()),
             error = function(e) character())
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
    config$species$active <- input$species
    config$species$catalog[[input$species]]$threshold <- list(
      type = input$threshold_type, value = input$threshold_value
    )
    # An empty multi-select means "all stages", which is what a NULL `stages`
    # already encodes, so it must not be stored as character(0).
    config$species$catalog[[input$species]]$stages <-
      if (length(input$stages) > 0) input$stages else NULL
    config$species$resolved <- taupatch:::resolve_species(config)

    config$dates$years <- input$years
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
    config$model$trees <- input$trees
    config$model$cv_folds <- input$cv_folds
    config$covariates$selected <- input$covariates
    config$covariates$bathymetry <- input$bathymetry %||% character()
    config$covariates$log_transform <- input$log_transform %||% character()
    config
  })

  output$config_yaml <- renderText({
    config <- current_config()
    config$species$resolved <- NULL
    yaml::as.yaml(config[c("paths", "columns", "species", "dates",
                            "study_area", "covariates", "model", "projection")])
  })

  observeEvent(input$run, {
    config <- current_config()

    withProgress(message = "Running taupatch", value = 0, {
      messages <- character()
      result <- tryCatch(
        withCallingHandlers({
          incProgress(0.1, detail = "loading data")
          if (config$covariates$source == "mock" && !file.exists(config$paths$zoop_file)) {
            generate_mock_zoop_data(config)
          }
          run_taupatch(config)
        }, message = function(m) {
          messages <<- c(messages, sub("\n$", "", conditionMessage(m)))
          incProgress(0.15, detail = sub("\n$", "", conditionMessage(m)))
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
        column(4, tags$small(tags$code(info$variable[i])))
      )
    })
    tagList(
      fluidRow(
        style = "padding-bottom: 6px; border-bottom: 2px solid #ccc; font-weight: bold;",
        column(2, "Name"), column(4, "Long name"),
        column(2, "Units"), column(4, "Copernicus variable")
      ),
      rows
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
    metrics <- run_result()$model$metrics
    data.frame(Metric = metrics$.metric, Mean = round(metrics$mean, 4),
               Folds = metrics$n)
  })

  output$importance <- renderPlot({
    req(run_result())
    plot_importance(run_result()$model$importance)
  })

  output$threshold <- renderText({
    req(run_result())
    paste0("Abundance threshold used: ", signif(run_result()$model$threshold, 6))
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
    tagList(
      fluidRow(
        column(5, selectInput("projection", "Month",
                              choices = stats::setNames(
                                seq_len(nrow(projections)),
                                paste(month.name[projections$month], projections$year)
                              ))),
        column(7, br(),
               downloadButton("download_projections",
                              paste0("Download ", downloadable, " GeoTIFFs (.zip)")))
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

  # Keep the log-transform choices in step with what is actually selected above.
  # updateSelectInput rather than re-rendering the control, so an existing
  # selection survives; a selection that is no longer available is dropped, since
  # config validation rejects a log-transform naming an unfetched covariate.
  observe({
    available <- c(input$covariates, input$bathymetry)
    labels <- c(covariate_choices, bathymetry_choices)
    choices <- labels[labels %in% available]

    updateSelectInput(session, "log_transform", choices = choices,
                      selected = intersect(isolate(input$log_transform), available))
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

  output$map <- leaflet::renderLeaflet({
    req(run_result(), input$projection)
    projections <- run_result()$projections
    projection_map(projections$geotiff[as.integer(input$projection)])
  })
}

shinyApp(ui, server)
