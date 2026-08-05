# Camille Ross
# 9 June, 2020
# Purpose: Load environmental covariate data for a given month and year

# -------- Load libraries --------
library(raster)
library(dplyr)
library(sf)

# -------- Source outside files --------
source("../calanus_data/Code/int_chl.R")

# -------- Load environmental covariates --------
#'@param fp_data <chr> file path to environmental covariate data
#'@param year <num> year for which to load data
#'@param month <num> month for which to load data
#'@param env_covars <vector> vector of covariates to load
#'@return covars <data.frame> covariates consolidated into a data frame object
load_covars <- function(fp_covars, year, month,
                        env_covars = "all",
                        as_raster = FALSE) {

  # -------- Initialize file paths --------
  # Wind filepath
  fp_wind <- file.path(fp_covars, "CCMP_Winds", "EC22", "wspd_monthly_5km")
  # Fetch filepath
  fp_fetch <- file.path(fp_covars, "Fetch")
  # Chlorophyll-a filepath -- GlobColour
  fp_chl <- file.path(fp_covars, "GlobColour_Chl", "EC22", "chl_monthly_5km")
  # HYCOM filepath
  fp_hycom <- file.path(fp_covars, "HYCOM", "EC22")
  # HYCOM bottom salinity filepath
  fp_bots <- file.path(fp_hycom, "bots_monthly_5km")
  # HYCOM bottom temperature filepath
  fp_bott <- file.path(fp_hycom, "bott_monthly_5km")
  # HYCOM surface salinity filepath
  fp_sss <- file.path(fp_hycom, "sss_monthly_5km")
  # HYCOM surface temperature filepath
  fp_sst <- file.path(fp_hycom, "sst_monthly_5km")
  # HYCOM current speed filepath
  fp_uv <- file.path(fp_hycom, "uv_monthly_5km")
  # MUR_SST filepath
  fp_mur_sst <- file.path(fp_covars, "MUR_SST", "EC22", "sst_monthly_5km")
  # Bathymetry filepath
  fp_bat <- file.path(fp_covars, "SRTM30_Bathymetric", "EC22")
  
  # -------- Load covariate data --------
  # ---- Load wind data ----
  wind <- raster::raster(file.path(fp_wind, year, paste0(year, "_month", 
                                                         dplyr::if_else(month < 10, paste0(0, month), as.character(month)),
                                                         "_mean.img")))

  # ---- Load fetch data ----
  fetch <- raster::raster(file.path(fp_fetch, "EC22_5km_AVG_Wind_Fetch_50km_16rad.img"))

  # ---- Load chlorophyll data ----
  chl <- raster::raster(file.path(fp_chl, year, paste0(year, "_month", 
                                                       dplyr::if_else(month < 10, paste0(0, month), as.character(month)),
                                                       "_mean.img")))
  
  # ---- Load integrated chlorophyll ----
  int_chl <- int_chl(fp_covars, year, month, as_raster = TRUE)
  
  # ---- Load HYCOM data ----
  # -- Load bottom salinity --
  bots <- raster::raster(file.path(fp_bots, year, paste0(year, "_month", 
                                                         dplyr::if_else(month < 10, paste0(0, month), as.character(month)),
                                                         "_mean.img")))
  # -- Load bottom temperature --
  bott <- raster::raster(file.path(fp_bott, year, paste0(year, "_month", 
                                                         dplyr::if_else(month < 10, paste0(0, month), as.character(month)),
                                                         "_mean.img")))
  # -- Load surface salinity --
  sss <- raster::raster(file.path(fp_sss, year, paste0(year, "_month", 
                                                       dplyr::if_else(month < 10, paste0(0, month), as.character(month)),
                                                       "_mean.img")))
  # -- Load sea surface temperature --
  sst <- raster::raster(file.path(fp_sst, year, paste0(year, "_month", 
                                                       dplyr::if_else(month < 10, paste0(0, month), as.character(month)),
                                                       "_mean.img")))
  month_lag <- if_else(month == 1, 12, month-1)
  lag_sst <- raster::raster(file.path(fp_sst, dplyr::if_else(month == 1, year-1, as.double(year)), paste0(dplyr::if_else(month == 1, year-1, as.double(year)), "_month", 
                                                      dplyr::if_else(month_lag < 10, paste0(0, month_lag), as.character(month_lag)),
                                                       "_mean.img")))
  
  # -- Compute SST gradient --
  sst_grad <- raster::terrain(sst)

  # -- Load current speed --
  uv <- raster::raster(file.path(fp_uv, year, paste0(year, "_month", 
                                                     dplyr::if_else(month < 10, paste0(0, month), as.character(month)),
                                                     "_mean.img")))
  
  # -- Compute current speed gradient
  uv_grad <- raster::terrain(uv)
  
  # ---- Load bathymetric data ----
  bat <- raster::raster(file.path(fp_bat, "EC22_Depth_1km_mean_5km.img"))
  
  # ---- Load distance to shore data ----
  dist <- raster::raster(file.path(fp_bat, "EC22_DistToShore_1km_mean_5km.img"))
  
  # ---- Load bathymetric slope data ----
  slope <- raster::raster(file.path(fp_bat, "EC22_Slope_1km_mean_5km.img"))
  
  if (as_raster) {
    jday <- slope 
    jday[slope != 0]<- lubridate::yday(as.Date(paste0(year, "-", month, "-15")))
  }

  # -------- Initialize new projection --------
  new_proj <- "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"
  
  # -------- Determine which covariates to use --------
  if ("all" %in% env_covars) {
    env_covars <- c("wind", "fetch", "chl", "int_chl",
                    "bots", "bott", "sss",
                    "sst", "lag_sst", "sst_grad", "uv", "uv_grad", "bat", 
                    "dist", "slope")
  }
  
  # -------- Organize data as a data frame or rasters depending on to_raster argument --------
  # ---- Organize as raster ----
  if (as_raster) {
    
    if ("all" %in% env_covars) {
      env_covars <- c("wind", "fetch", "chl", "int_chl",
                      "bots", "bott", "sss",
                      "sst", "lag_sst", "sst_grad", "uv", "uv_grad", "bat", 
                      "dist", "slope", "jday")
    }
    # Create raster stack of selected covariates
    covars <- raster::stack(wind, fetch, chl, int_chl,
                            bots, bott, sss,
                            sst, lag_sst, sst_grad, uv, uv_grad, bat,
                            dist, slope, jday)
    # Set names of raster brick
    names(covars) <- c("wind", "fetch", "chl", "int_chl",
                       "bots", "bott", "sss",
                       "sst", "lag_sst", "sst_grad", "uv", "uv_grad","bat",
                       "dist", "slope", "jday")
    # Project covariates
    covars <- raster::projectRaster(covars, crs=new_proj)
    # Subset covariates
    covars <- raster::subset(covars, env_covars)
    # Create mask
    mask <- as(extent(-82.64935, -55.95385, 35, 47.99483), 'SpatialPolygons')
    # Set coordinate system of mask
    crs(mask) <- crs(covars)
    # Crop extent of covariates
    covars <- crop(covars, mask)
    # Convert to raster stack
    covars <- stack(covars)
  } else { # ---- Organize as dataframe ----
    # Convert covariate raster to dataframes
    wind <- as.data.frame(wind, xy = TRUE)
    fetch <- as.data.frame(fetch, xy = TRUE)
    chl <- as.data.frame(chl, xy = TRUE)
    int_chl <- as.data.frame(int_chl, xy = TRUE)
    bots <- as.data.frame(bots, xy = TRUE)
    bott <- as.data.frame(bott, xy = TRUE)
    sss <- as.data.frame(sss, xy = TRUE)
    sst <- as.data.frame(sst, xy = TRUE)
    lag_sst <- as.data.frame(lag_sst, xy = TRUE)
    sst_grad <- as.data.frame(sst_grad, xy = TRUE)
    uv <- as.data.frame(uv, xy = TRUE)
    uv_grad <- as.data.frame(uv_grad, xy = TRUE)
    bat <- as.data.frame(bat, xy = TRUE)
    dist <- as.data.frame(dist, xy = TRUE)
    slope <- as.data.frame(slope, xy = TRUE)
    # Create named list of covariates
    covars <- list("wind" = wind, "fetch" = fetch, "chl" = chl, 
                   "int_chl" = int_chl, "bots" = bots, "bott" = bott, 
                   "sss" = sss, "sst" = sst, "lag_sst" = lag_sst, "sst_grad" = sst_grad, "uv" = uv, 
                   "uv_grad" = uv_grad, "bat" = bat, "dist" = dist, "slope" = slope)
    # Merge dataframes into comprehensive dataframe of selected covariates
    covars <- Reduce(function(x,y) dplyr::inner_join(x = x, y = y, by = c("x", "y")), 
                     covars[env_covars])
    # Rename columns
    names(covars) <- c("lon", "lat", env_covars)
    # Convert coordinates from meters into latitude and longitude
    lonlat <- sf::st_as_sf(x = covars,
                           coords = c("lon", "lat"),
                           crs = "+proj=aea +lat_1=27.33333333333333 +lat_2=40.66666666666666 +lat_0=34 +lon_0=-78 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs +ellps=WGS84 +towgs84=0,0,0") %>%
      sf::st_transform(crs = new_proj) %>%
      sf::st_coordinates() %>%
      as.data.frame()
    # Reassign to original dataframe
    covars[c("lon", "lat")] <- lonlat
  }
  # -------- Return covariates --------
  return(covars)
}









 