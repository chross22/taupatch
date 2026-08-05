# Camille Ross
# 9 June, 2020
# Purpose: Combine zooplankton data and environmental covariate data into one CSV file for use as model input

# -------- Load libraries --------
library(raster)
library(dplyr)
library(readr)

# -------- Source outside function --------
# Source function to load covariates
source("load_covars.R")

# -------- Format data function --------
#'@param fp_data <chr> file path to zooplankton database
#'@param fp_covars <chr> file path to covariate data
#'@param fp_out <chr> file path to where the output is saved
#'@param covars <vector> vector of covariates to include in the formatted data
#'@param years <vector> vector of years to include in the formatted data
format_model_data <- function(fp_data = "./Data/EcoMon", 
                              fp_covars = "./Data/Environmental", 
                              fp_out = "./Data/Formatted",
                              env_covars = "all",
                              years = 2000:2023) {
  # -------- Create directory to store files --------
  # Create directory
  if (!dir.exists(fp_out)) {
    dir.create(path = fp_out, showWarnings = FALSE)
  }
  # -------- Load zooplankton database --------
  # Load zooplankton database
  db <- readr::read_csv(fp_data, show_col_types = FALSE) |>
    filter(year >= min(years) & year <= max(years))
  # Negate non-negative longitude values
  db$lon[db$lon > 0] <- -db$lon[db$lon > 0]
  # Round the latitude and longitude to 2 decimal places
  db$lat <- round(db$lat, digits = 1)
  db$lon <- round(db$lon, digits = 1)
  
  print(env_covars)
  
  # -------- Loop over years and months --------
  # Loop over years
  for (i in years) {
    print(i)
    # Isolate zooplankton data for current year
    year_data <- db |> filter(year == i)
    # Initialize months present in year data
    months <- sort(unique(year_data$month))
    # Loop over months
    for (j in months) {
      print(j)
      # Isolate zooplankton data for current month
      month_data <- year_data |> filter(month == j)
      # Load environmental covariates
      covars <- load_covars(fp_covars = fp_covars, year = i, month = j, 
                            env_covars = env_covars)
      # Round latitude and longitude to 2 decimal places
      covars$lat <- round(covars$lat, digits = 1)
      covars$lon <- round(covars$lon, digits = 1)
      # Initialize combined data object if iteration is first month and year
      if (j == min(months)) {
        # Join zooplankton data and covariates
        full_data <- dplyr::left_join(month_data, covars, by  = c("lon", "lat")) |>
          # Add presence absence values
          dplyr::mutate(cfin_pa = dplyr::if_else(is.na(cfin_total), 0, 1),
                        ctyp_pa = dplyr::if_else(is.na(ctyp_total), 0, 1),
                        pseudo_pa = dplyr::if_else(is.na(pseudo_total), 0, 1),
                        jday = lubridate::yday(as.Date((paste0(year, "-", month, "-", day)))))
      } else {
        # Join zooplankton data and covariates
        temp_data <- dplyr::left_join(month_data, covars, by  = c("lon", "lat")) |>
          # Add presence absence values
          dplyr::mutate(cfin_pa = dplyr::if_else(is.na(cfin_total), 0, 1),
                        ctyp_pa = dplyr::if_else(is.na(ctyp_total), 0, 1),
                        pseudo_pa = dplyr::if_else(is.na(pseudo_total), 0, 1),
                        jday = lubridate::yday(as.Date((paste0(year, "-", month, "-", day)))))
        # Bind temporary and full dataframes
        full_data <- rbind(full_data, temp_data)
      }
      # Keep only one entry for each latitude and longitude
      full_data <- full_data |> distinct(lon, lat, cfin_total, ctyp_total, pseudo_total, .keep_all = TRUE)
    }
    # Write year data to CSV
    readr::write_csv(x = full_data, path = file.path(fp_out, paste0(i, ".csv")))
  }
}


