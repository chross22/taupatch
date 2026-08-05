
# Source covariate loading function
source("load_covars.R")

# -------- Main function --------
#'@param fp_covars <chr> file path to environmental covariate data
#'@param env_covars <vector> vector of covariates to include in the model
#'@param month <numeric> month for which to produce the climatology
get_climatology <- function(fp_covars, env_covars, month) {
  
  clim <- load_covars(fp_covars = fp_covars, year = 2000, month = month,
                      env_covars = env_covars,
                      as_raster = TRUE)
  
  if ("wind" %in% env_covars) {
    wind <- clim$wind
  }
  if ("fetch" %in% env_covars) {
    fetch <- clim$fetch
  }
  if ("chl" %in% env_covars) {
    chl <- clim$chl
  }
  if ("int_chl" %in% env_covars) {
    int_chl_var <- clim$int_chl
  }
  if ("bots" %in% env_covars) {
    bots <- clim$bots
  }
  if ("bott" %in% env_covars) {
    bott <- clim$bott
  }
  if ("sss" %in% env_covars) {
    sss <- clim$sss
  }
  if ("sst" %in% env_covars) {
    sst <- clim$sst
  }
  if ("lag_sst" %in% env_covars) {
    lag_sst <- clim$lag_sst
  }
  if ("sst_grad" %in% env_covars) {
    sst_grad <- clim$sst_grad
  }
  if ("uv" %in% env_covars) {
    uv <- clim$uv
  }
  if ("uv_grad" %in% env_covars) {
    uv_grad <- clim$uv_grad
  }
  if ("bat" %in% env_covars) {
    bat <- clim$bat
  }
  if ("dist" %in% env_covars) {
    dist <- clim$dist
  }
  if ("slope" %in% env_covars) {
    slope <- clim$slope
  }
  if ("jday" %in% env_covars) {
    jday <- clim$jday
  }
  
  for (i in 2001:2017) {
    clim <- load_covars(fp_covars = fp_covars, year = i, month = month,
                        env_covars = env_covars,
                        as_raster = TRUE)
    
    if ("wind" %in% env_covars) {
      wind <- raster::stack(clim$wind, wind)
    }
    if ("fetch" %in% env_covars) {
      fetch <- raster::stack(clim$fetch, fetch)
    }
    if ("chl" %in% env_covars) {
      chl <- raster::stack(clim$chl, chl)
    }
    if ("int_chl" %in% env_covars) {
      int_chl_var <- raster::stack(clim$int_chl, int_chl_var)
    }
    if ("bots" %in% env_covars) {
      bots <- raster::stack(clim$bots, bots)
    }
    if ("bott" %in% env_covars) {
      bott <- raster::stack(clim$bott, bott)
    }
    if ("sss" %in% env_covars) {
      sss <- raster::stack(clim$sss, sss)
    }
    if ("sst" %in% env_covars) {
      sst <- raster::stack(clim$sst, sst)
    }
    if ("lag_sst" %in% env_covars) {
      lag_sst <- raster::stack(clim$lag_sst, lag_sst)
    }
    if ("sst_grad" %in% env_covars) {
      sst_grad <- raster::stack(clim$sst_grad, sst_grad)
    }
    if ("uv" %in% env_covars) {
      uv <- raster::stack(clim$uv, uv)
    }
    if ("uv_grad" %in% env_covars) {
      uv_grad <- raster::stack(clim$uv_grad, uv_grad)
    }
    if ("bat" %in% env_covars) {
      bat <- raster::stack(clim$bat, bat)
    }
    if ("dist" %in% env_covars) {
      dist <- raster::stack(clim$dist, dist)
    }
    if ("slope" %in% env_covars) {
      slope <- raster::stack(clim$slope, slope)
    }
    if ("jday" %in% env_covars) {
      jday <- raster::stack(clim$jday, jday)
    }
    
  }
  
  if ("wind" %in% env_covars) {
    wind <- raster::calc(wind, fun = mean, na.rm = TRUE)
  }
  if ("fetch" %in% env_covars) {
    fetch <- raster::calc(fetch, fun = mean, na.rm = TRUE)
  }
  if ("chl" %in% env_covars) {
    chl <- raster::calc(chl, fun = mean, na.rm = TRUE)
  }
  if ("int_chl" %in% env_covars) {
    int_chl_var <- raster::calc(int_chl_var, fun = mean, na.rm = TRUE)
  }
  if ("bots" %in% env_covars) {
    bots <- raster::calc(bots, fun = mean, na.rm = TRUE)
  }
  if ("bott" %in% env_covars) {
    bott <- raster::calc(bott, fun = mean, na.rm = TRUE)
  }
  if ("sss" %in% env_covars) {
    sss <- raster::calc(sss, fun = mean, na.rm = TRUE)
  }
  if ("sst" %in% env_covars) {
    sst <- raster::calc(sst, fun = mean, na.rm = TRUE)
  }
  if ("lag_sst" %in% env_covars) {
    lag_sst <- raster::calc(lag_sst, fun = mean, na.rm = TRUE)
  }
  if ("sst_grad" %in% env_covars) {
    sst_grad <- raster::calc(sst_grad, fun = mean, na.rm = TRUE)
  }
  if ("uv" %in% env_covars) {
    uv <- raster::calc(uv, fun = mean, na.rm = TRUE)
  }
  if ("uv_grad" %in% env_covars) {
    uv_grad <- raster::calc(uv_grad, fun = mean, na.rm = TRUE)
  }
  if ("bat" %in% env_covars) {
    bat <- raster::calc(bat, fun = mean, na.rm = TRUE)
  }
  if ("dist" %in% env_covars) {
    dist <- raster::calc(dist, fun = mean, na.rm = TRUE)
  }
  if ("slope" %in% env_covars) {
    slope <- raster::calc(slope, fun = mean, na.rm = TRUE)
  }
  if ("jday" %in% env_covars) {
    jday <- raster::calc(jday, fun = mean, na.rm = TRUE)
  }
  
  clim <- raster::stack(if ("wind" %in% env_covars) {wind}, 
                        if ("fetch" %in% env_covars) {fetch}, 
                        if ("chl" %in% env_covars) {chl}, 
                        if ("int_chl" %in% env_covars) {int_chl_var}, 
                        if ("bots" %in% env_covars) {bots},
                        if ("bott" %in% env_covars) {bott}, 
                        if ("sss" %in% env_covars) {sss}, 
                        if ("sst" %in% env_covars) {sst}, 
                        if ("lag_sst" %in% env_covars) {lag_sst}, 
                        if ("sst_grad" %in% env_covars) {sst_grad},
                        if ("uv" %in% env_covars) {uv}, 
                        if ("uv_grad" %in% env_covars) {uv_grad}, 
                        if ("bat" %in% env_covars) {bat}, 
                        if ("dist" %in% env_covars) {dist}, 
                        if ("slope" %in% env_covars) {slope}, 
                        if ("jday" %in% env_covars) {jday})
  
  names(clim) <- c(if ("wind" %in% env_covars) {"wind"}, 
                   if ("fetch" %in% env_covars) {"fetch"}, 
                   if ("chl" %in% env_covars) {"chl"}, 
                   if ("int_chl" %in% env_covars) {"int_chl"}, 
                   if ("bots" %in% env_covars) {"bots"},
                   if ("bott" %in% env_covars) {"bott"}, 
                   if ("sss" %in% env_covars) {"sss"}, 
                   if ("sst" %in% env_covars) {"sst"}, 
                   if ("lag_sst" %in% env_covars) {"lag_sst"}, 
                   if ("sst_grad" %in% env_covars) {"sst_grad"},
                   if ("uv" %in% env_covars) {"uv"}, 
                   if ("uv_grad" %in% env_covars) {"uv_grad"}, 
                   if ("bat" %in% env_covars) {"bat"}, 
                   if ("dist" %in% env_covars) {"dist"}, 
                   if ("slope" %in% env_covars) {"slope"}, 
                   if ("jday" %in% env_covars) {"jday"})
  
  return(clim)
  
}

# for (month in 1:12) {
#   
#   print(month)
#   
#   clim <- get_climatology(fp_covars, env_covars, month)
# 
#   writeRaster(clim, filename = file.path("Env_Covars/Climatology", paste0("climatology_all_covars_", month, ".grd")), overwrite = TRUE)
#   
# }
