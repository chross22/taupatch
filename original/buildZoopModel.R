# Camille H. Ross
# 6 Nov. 2023
# Purpose: Run BIOMOD random forest to model zooplankton tau-patch
# SETUP: Set working directory to source file location
# Citation: Ross et al. (2023)

# -------- Load libraries --------
require(dplyr)
require(readr)
require(viridis)
require(Metrics)
require(mapdata)
require(maps)
require(ggplot2)
require(stats)
require(biomod2)
require(ff)
require(yaml)

# -------- Source outside files --------
# Source data formatting function
source("format_model_data.R")
# Source covariate loading function
source("load_covars.R")
# Source covariate loading function
source("get_climatology.R")
# Source data binding function
source("../calanus_data/Code/bind_years.R")

# --- Example parameters for line-by-line function testing
if (FALSE){
  version = "vtest.ben.nick"
  fp_md = "../calanus_data/Data/Databases/zooplankton_covar_data"
  species = "ctyp"
  biomod_dataset = "ECOMON"
  fp_covars = "../Env_Covars"
  env_covars = c("wind", "int_chl", "sst", "jday") #, "uv_grad", "bat", "slope", "bots", "bott")
  years = 2003:2006
  fp_out = "../Models.Test.ben.nick"
  threshold = 0.9
  format_data = TRUE
}

# -------- Main function --------
#'@param version <chr> version of model
#'@param fp_md <chr> file path to formatted data used in model
#'@param species <chr> species to model; choices are "cfin", "ctyp", or "pseudo"
#'@param biomod_dataset <chr> dataset from zooplankton database to be used; choices include "ECOMON", "ECOMON_STAGED", "CPR", etc.
#'@param fp_covars <chr> file path to environmental covariate data
#'@param env_covars <vector> vector of covariates to include in the model; 
#'all options for covars: "wind", "fetch", "chl", 
#'                        "int_chl", "bots", "bott", 
#'                        "sss", "sst", "lag_sst", 
#'                        "sst_grad", "uv", "uv_grad", 
#'                        "bat",  "dist", "slope"
#'Derived covariate definitions:
#'"int_chl" = time-integrated or cumulative chlorophyll
#'"lag_sst" = sst with 1-month lag
#'"sst_grad" = gradient of sst
#'"uv_grad" = gradient of current velocity magnitude 
#'@param years <vectors> years for which to run the model
#'@param fp_out <chr> file path save the data to 
#'@param threshold <numeric> threshold to model (individuals/m2); must be > 1
#'                           OR percentile in data from which to draw threshold 
#'                           (e.g., values of 0.9 would use 90th percentile as threshold); must be < 1
#'@param overwrite_proj <logical> whether or not to overwrite existing projection files
#'@param format_data <logical> if true, data is formatted within function; only used if model_data is NULL
#'@param fp_zpd <chr> filepath to the zooplankton database if data is formatted within function
buildZoopModel <- function(version, fp_md, species, biomod_dataset, fp_covars, env_covars, 
                         years, fp_out, threshold, overwrite_proj = TRUE,
                         format_data = FALSE, fp_zpd = NULL) {
  
  # -------- Create output directories --------
  dir.create(fp_out, showWarnings = FALSE) 
  dir.create(file.path(fp_out, species), showWarnings = FALSE)
  dir.create(file.path(fp_out, species, version), showWarnings = FALSE)
  dir.create(file.path(fp_out, species, version, "Biomod"), showWarnings = FALSE)
  # -------- Create directory for projections --------
  dir.create(file.path(fp_out, species, version, "Biomod", "Projections"), showWarnings = FALSE)
  # -------- Create directory for plots --------
  dir.create(file.path(fp_out, species, version, "Biomod", "Plots"), showWarnings = FALSE)
  # -------- Create directory for interactions --------
  dir.create(file.path(fp_out, species, version, "Biomod", "Evals"), showWarnings = FALSE)
  
  # Fetch month names
  months <- month.name
  
  # -------- Format model data --------
  if (format_data) {
    # Format zooplankton and environmental covariate data
    format_model_data(fp_data = fp_zpd, fp_covars = fp_covars, env_covars = "all", years = years, fp_out = fp_md)
  }
  
  # -------- Load model data --------
  if (length(years) == 1) {
    md <- readr::read_csv(file.path(fp_md, paste0(years[1], ".csv"))) |> 
      dplyr::filter(dataset %in% biomod_dataset)
  } else {
    md <- bind_years(fp = file.path(fp_md), years = years) |>
      dplyr::filter(dataset %in% biomod_dataset)
  }
  
  # -------- format columns --------
  if (species == "cfin") {
    md$abund <- as.data.frame(md[paste0(species, "_total")])$cfin_total
  } else if (species == "ctyp") {
    md$abund <- as.data.frame(md[paste0(species, "_total")])$ctyp_total
  } else if (species == "pseudo") {
    md$abund <- as.data.frame(md[paste0(species, "_total")])$pseudo_total
  }
  
  # -------- Exclude NAs and select columns --------

  md <- md |>
    as.data.frame() |>
    dplyr::select(dplyr::any_of(c("station", "year", "month", "day", "lat", "lon", "dataset", 
                  "cfin_total", "ctyp_total", "pseudo_total", 
                  "wind", "fetch", "chl", "int_chl", "bots", "bott", "sss", "sst", 
                  "lag_sst", "sst_grad", 
                  "uv", "uv_grad", 
                  "bat", "dist", "slope", 
                  "cfin_pa", "ctyp_pa", 
                  "pseudo_pa", 
                  "jday", "abund"))) |>
    na.exclude() |>
    dplyr::mutate(jday = as.Date(paste(year, month, day, sep = "-")) |>
                    format("%j") |>
                    as.numeric(),
                  season = if_else(month %in% c(1:3), 1,
                                   if_else(month %in% c(4:6), 2,
                                           if_else(month %in% c(7:9), 3, 4))))
  
  # -------- Take natural log of bathymetry and chlorophyll --------
  md$chl <- log(abs(md$chl))
  md$int_chl <- log(abs(md$int_chl))
  md$bat <- log(abs(md$bat))
  
  # -------- Load world map data --------
  worldmap <- ggplot2::map_data("world")
  
  modelOptions <- BIOMOD_ModelingOptions()
  
  # -------- See if using raw threshold or percentile method --------
  if (threshold < 1) { # Only runs if percentile method selected (i.e., threshold parameter < 1)
    x <- md$abund
    threshold <- quantile(x, probs = c(threshold))
  }
  
  print(paste("--- THRESHOLD USED:", threshold, "---"))
  
  # -------- Isolate month data --------
  trainingData <- md
  # -------- Select presence or absence based on right whale feeding threshold --------
  trainingData$pa <- if_else(trainingData$abund < threshold, 0, 1)
  
  if (nrow(trainingData) < 100 | length(unique(trainingData$pa)) != 2) {
    print("skipped")
    next
  }
  
  # Isolate binary presence/absence data
  trainingPA <- as.data.frame(trainingData[,'pa'])
  # Isolate presence/absence coordiantes
  trainingXY <- trainingData[,c('lon', 'lat')]
  # Isolate environmental covariates
  # Select variables based on month
  trainingCovars <- as.data.frame(trainingData[, env_covars])
  
  # Format data for use in Biomod2 modelling function
  biomodData <- BIOMOD_FormatingData(resp.var = trainingPA,
                                     expl.var = trainingCovars,
                                     resp.xy = trainingXY,
                                     resp.name = paste0(species, version))
  
  print("--- DATA FORMATTED ----")
  
  orig_dir = setwd(fp_out)
  # ---------------------- BUILD MODELS ----------------------
  modelOut <- BIOMOD_Modeling(bm.format = biomodData,
                              modeling.id = paste0(species, version),
                              models = c("RF"),
                              bm.options = modelOptions,
                              CV.nb.rep = 10,
                              data.split.perc = 70,
                              prevalence = 0.5,
                              var.import = 5,
                              metric.eval = c('ROC', 'TSS', 'KAPPA'),
                              scale.models = FALSE,
                              do.progress = TRUE)
  setwd(orig_dir)
  print("--- MODEL RUN ----")
  
  # ---------------------- SAVE EVALUATIONS & VARIABLE CONTRIBUTION ----------------------
  # Retrieves model evaluations
  #'@param obj <BIOMOD.models.out> model produced using BIOMOD_Modeling
  #'@param as.data.frame <boolean> if TRUE, function returns evaluations as a dataframe
  modelEvals <- get_evaluations(obj = modelOut)
  # Saves model evaluations to a csv file in the results directory
  # Allows for easy analysis
  write.csv(modelEvals, file = file.path(fp_out, species, version, "Biomod", "Evals", paste0("evals.csv")), row.names = TRUE)
  
  # Retrieves variable contribution
  #'@param obj <BIOMOD.models.out> model produced using BIOMOD_Modeling
  #'@param as.data.frame <boolean> if TRUE, function returns variable contributions as a dataframe
  varImportance <- get_variables_importance(obj = modelOut)
  # Saves model evaluations to a csv file in the results directory
  # Allows for easy analysis
  write.csv(varImportance, file = file.path(fp_out, species, version, "Biomod", "Evals", paste0("var_importance.csv")), row.names = TRUE)
  
  print("--- DIAGNOSTIC METRICS SAVED ----")
  
  pdf(file.path(fp_out, species, version, "Biomod", "Plots", "response_curves.pdf"))
  par(mar=c(3,3,3,3))
  # Plot RF response curves; check biological plausibility
  bm_PlotResponseCurves(bm.out = modelOut,
    models.chosen = "all",
    new.env = get_formal_data(modelOut, "expl.var"),
    show.variables = get_formal_data(modelOut, "expl.var.names"),
    fixed.var = "mean",
    do.bivariate = FALSE,
    do.plot = TRUE,
    do.progress = TRUE)
  dev.off()
  
  print("--- PROJECTIONS INITIATED ---")
  
  # ------- Create monthly projections by year --------
  for (j in 1:12) {
    
    for (i in years) {
      
      print(paste("--- PROJECTING:", months[j], i, "---"))
      
      # -------- Load environmental covariates for projection --------
      covars <- load_covars(fp_covars = fp_covars, year = i, month = j,
                            env_covars = env_covars,
                            as_raster = TRUE)

      # ------- Project RF -------
      # Create vector all runs of model algorithm for projection
      select_models <- c()
      for (k in 1:10) {
        select_models[k] <- paste0(species, version, "_allData_RUN", k, "_RF")
      }
      
      rfProj <- BIOMOD_Projection(bm.mod = modelOut,
                                  new.env = covars,
                                  proj.name = paste0("RF_",  i, "_", j),
                                  models.chosen = select_models,
                                  metric.binary = 'ROC',
                                  compress = TRUE,
                                  build.clamping.mask = TRUE)
      
      
      # Load projection as raster
      # Divide by 1000 to convert probabilities to [0,1] scale
      rf_proj_raster <- raster(rfProj@proj.out@link[1]) %>%
        `/`(1000)
      
      proj_filename <- file.path(fp_out, species, version, "Biomod", "Projections", rfProj@proj.name)
      
      if (!file.exists(proj_filename) | overwrite_proj) {
        raster::writeRaster(rf_proj_raster, 
                            filename = proj_filename,
                            overwrite = overwrite_proj)
      }
      
      crs(rf_proj_raster) <- '+init=epsg:4121 +proj=longlat +ellps=GRS80 +datum=GGRS87 +no_defs +towgs84=-199.87,74.79,246.62'
      
      # Save projection raster as data frame with xy coords and no NAs
      rf_proj_df <- as.data.frame(rf_proj_raster, xy = TRUE, na.rm = TRUE)
      
      # Assign column names
      names(rf_proj_df) <- c('x', 'y', 'pred')
      
      # -------- Plot projection --------
      ggplot() + 
        # Add projection data
        geom_tile(data = rf_proj_df, aes(x, y, fill = pred)) +
        # Add projection color gradient and label
        scale_fill_gradientn(colors = inferno(500), limits = c(0,1), na.value = "white") +
        labs(x = "", 
             y = "") +
        ggtitle(paste0(months[j], ", ", i)) +
        # Add world map data
        geom_polygon(data = worldmap, aes(long, lat, group = group), fill = NA, colour = "gray43") +
        coord_quickmap(xlim = c(round(min(rf_proj_df$x)), round(max(rf_proj_df$x))), 
                       ylim = c(round(min(rf_proj_df$y)), round(max(rf_proj_df$y))),
                       expand = TRUE) +
        # Remove grid lines
        theme_bw() +
        theme(panel.grid.major = element_blank(), 
              panel.grid.minor = element_blank(),
              legend.position = "none",
              legend.title = element_blank(),
              plot.title = element_text(size=22))
        # Save plot to hard drive
      
      ggsave(filename = file.path(fp_out, species, version, "Biomod", "Plots", paste0("rf_proj_",  i, "_", j, ".png")), width = 7, height = 7)    
      
    }
  }
  
  print(paste("--- MODEL OUTPUT FOUND HERE: ", fp_out, "---"))
  
  return(threshold)
}