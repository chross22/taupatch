# Camille Ross
# 9 June, 2020
# Purpose: Integrate chlorophyll layer

# -------- Load libraries --------
library(raster)
library(dplyr)

# -------- Load environmental covariates --------
#'@param fp_data <chr> file path to environmental covariate data
#'@param year <num> year for which to load data
#'@param month <num> month for which to load data
#'@param env_covars <vector> vector of covariates to load
#'@return covars <data.frame> covariates consolidated into a data frame object
int_chl <- function(fp_covars, year, month,
                    as_raster = FALSE) {
  # -------- Initialize file path --------
  # Chlorophyll-a filepath -- GlobColour
  fp_chl <- file.path(fp_covars, "GlobColour_Chl", "EC22", "chl_monthly_5km")
  
  # -------- Load chlorophyll data --------
  chl <- raster::raster(file.path(fp_chl, year, paste0(year, "_month01_mean.img")))
  if (month != 1) {
    for (i in 2:month) {
      chl <- raster::stack(chl, raster::raster(file.path(fp_chl, year, paste0(year, "_month", 
                                                       dplyr::if_else(i < 10, paste0(0, i), as.character(i)),
                                                       "_mean.img"))))
    }
  }
  # -------- Sum data --------
  chl <- sum(chl)
  # -------- Convert to dataframe --------
  if (!as_raster) {
    chl <- as.data.frame(chl, xy = TRUE)
  }
  # -------- Return integrated chlorophyll layer --------
  return(chl)
}
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  