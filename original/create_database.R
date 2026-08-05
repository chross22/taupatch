# Camille Ross
# Nov 28, 2024
# Purpose: Compile individual calanus datasets into comprehensive database for C.finmarchicus

# -------- Load libraries --------
library(readr)
library(raster)
library(ggplot2)
library(dplyr)
library(lubridate)
library(fs)

# -------- Initialize filepaths --------
# Data file path
fp_data <- "../Data"
# ECOMON file path
ecomon <- file.path(fp_data, "EcoMon")
# Databases file path
fp_db <- file.path(fp_data, "Databases")
if (!is_dir(fp_db)) {dir.create(fp_db)}

# -------- Load ECOMON data ---------
# Read in data -- version 3.5
ecomon_dat <- readr::read_csv(file.path(fp_ecomon, "EcoMon_Plankton_Data_v3_5.csv")) |>
  # Break up date and time into individual units
  # Add missing columns for consistency across datasets
  dplyr::mutate(year = lubridate::year(as.Date(date, format = '%d-%b-%y')),
                month = lubridate::month(as.Date(date, format = '%d-%b-%y')),
                day = lubridate::day(as.Date(date, format = '%d-%b-%y')),
                hour = lubridate::hour(lubridate::hms(time)),
                minute = lubridate::minute(lubridate::hms(time)),
                cfin_CI = 0,
                cfin_CII = 0,
                cfin_CIII = 0,
                cfin_CIV = 0,
                cfin_CVI = 0,
                cfin_CV = 0,
                cfin_CI_IV = 0,
                cfin_CV_VI = calfin_10m2/10,
                ctyp_adult = ctyp_10m2/10,
                ctyp_CIII = 0,
                ctyp_CIV = 0,
                ctyp_CV = 0,
                ctyp_C = 0,
                ctyp_IV_V = 0,
                ctyp_IV_VI = 0,
                ctyp_CVI = 0,
                ctyp_CV_CVI = 0,
                pseudo_adult = pseudo_10m2/10,
                pseudo_CII = 0,
                pseudo_CV = 0,
                pseudo_C = 0,
                pseudo_CVI = 0,
                pseudo_CI_IV = 0,
                dataset = "ECOMON") |>
  # Select relevant columns
  dplyr::select(station, year, month, day, lat, lon,
                cfin_CI, cfin_CII, cfin_CIII,
                cfin_CIV, cfin_CVI, cfin_CV,
                cfin_CI_IV, cfin_CV_VI, ctyp_adult,
                ctyp_CIII, ctyp_CIV, ctyp_CV,
                ctyp_C, ctyp_IV_V, ctyp_IV_VI,
                ctyp_CVI, ctyp_CV_CVI, pseudo_adult,
                pseudo_CII, pseudo_CV, pseudo_C,
                pseudo_CVI, pseudo_CI_IV, dataset)
# Read in data -- version from Harvey
ecomon_staged_dat <- readr::read_csv(file.path(fp_ecomon, "EcoMon_CalfinStage_Thru_12_30_2019_10m2.csv")) |>
  # Break up date and time into individual units
  # Add missing columns for consistency across datasets
  dplyr::mutate(year = lubridate::year(as.Date(date, format = '%d-%b-%y')),
                month = lubridate::month(as.Date(date, format = '%d-%b-%y')),
                day = lubridate::day(as.Date(date, format = '%d-%b-%y')),
                lat = latitude,
                lon = longitude,
                cfin_CI = c1_10m2/10,
                cfin_CII = c2_10m2/10,
                cfin_CIII = c3_10m2/10,
                cfin_CIV = c4_10m2/10,
                cfin_CVI = c6_10m2/10,
                cfin_CV = c5_10m2/10,
                cfin_CI_IV = c1_10m2/10 + c2_10m2/10 +
                  c3_10m2/10 + c4_10m2/10,
                cfin_CV_VI = c5_10m2/10 + c6_10m2/10,
                ctyp_adult = total_10m2/10,
                ctyp_CIII = 0,
                ctyp_CIV = 0, 
                ctyp_CV = 0,
                ctyp_C = 0, 
                ctyp_IV_V = 0, 
                ctyp_IV_VI = 0,
                ctyp_CVI = 0,
                ctyp_CV_CVI = 0, 
                pseudo_adult = 0,
                pseudo_CII = 0,
                pseudo_CV = 0, 
                pseudo_C = 0, 
                pseudo_CVI = 0, 
                pseudo_CI_IV = 0,
                dataset = "ECOMON_STAGED") |>
  # Select relevant columns
  dplyr::select(station, year, month, day, lat, lon,
                cfin_CI, cfin_CII, cfin_CIII,
                cfin_CIV, cfin_CVI, cfin_CV,
                cfin_CI_IV, cfin_CV_VI, ctyp_adult,
                ctyp_CIII, ctyp_CIV, ctyp_CV,
                ctyp_C, ctyp_IV_V, ctyp_IV_VI,
                ctyp_CVI, ctyp_CV_CVI, pseudo_adult, 
                pseudo_CII, pseudo_CV, pseudo_C, 
                pseudo_CVI, pseudo_CI_IV, dataset)

# -------- Load mbon data --------
# Read in headers
mbon_header <- readr::read_csv(file.path(fp_mbon, "Runge_calanus_abundance_2002-2016.csv"), n_max = 2, col_names = FALSE)
# Concatonate fist and second row of headers
mbon_header <- paste0(mbon_header[1,], mbon_header[2,])
# Read in data
mbon_dat_1 <- readr::read_csv(file.path(fp_mbon, "Runge_calanus_abundance_2002-2016.csv"), skip = 2, col_names = FALSE)
# Reattach headers to mbon_dat
names(mbon_dat_1) <- mbon_header
# Add missing columns
mbon_dat_1 <- mbon_dat_1 |>
  # Select relevant columns
  dplyr::select(stationstation, YearYear, MonthMonth, DayDay, 
                LatLat, LongLong, 
                `Calanus finmarchicus (no/m2)CI`,       
                `Calanus finmarchicus (no/m2)CII`,
                `Calanus finmarchicus (no/m2)CIII`,
                `Calanus finmarchicus (no/m2)CIV`,
                `Calanus finmarchicus (no/m2)CV`) |>
  # Rename columns
  dplyr::rename(station = stationstation, year = YearYear, 
                month = MonthMonth, day = DayDay, 
                lat = LatLat, lon = LongLong, 
                cfin_CI = `Calanus finmarchicus (no/m2)CI`,       
                cfin_CII = `Calanus finmarchicus (no/m2)CII`,
                cfin_CIII = `Calanus finmarchicus (no/m2)CIII`,
                cfin_CIV = `Calanus finmarchicus (no/m2)CIV`,
                cfin_CV = `Calanus finmarchicus (no/m2)CV`) |>
  # Add missing columns for consistency across datasets
  dplyr::mutate(cfin_CVI = NA,
                cfin_CI_IV = NA,
                cfin_CV_VI = NA,
                ctyp_adult = NA,
                ctyp_CIII = NA,
                ctyp_CIV = NA, 
                ctyp_CV = NA,
                ctyp_C = NA, 
                ctyp_IV_V = NA, 
                ctyp_IV_VI = NA,
                ctyp_CVI = NA,
                ctyp_CV_CVI = NA, 
                pseudo_adult = NA,
                pseudo_CII = NA,
                pseudo_CV = NA, 
                pseudo_C = NA, 
                pseudo_CVI = NA, 
                pseudo_CI_IV = NA,
                dataset = "MBON")

# -------- Load CPR data --------
# Read in headers
cpr_header <- readr::read_csv(file.path(fp_cpr, "GOMCPR_trim_cop.csv"), n_max = 2, col_names = FALSE)
# Concatonate fist and second row of headers
cpr_header <- paste0(cpr_header[1,], cpr_header[2,])
# Read in data
cpr_dat <- readr::read_csv(file.path(fp_cpr, "GOMCPR_trim_cop.csv"), skip = 2, col_names = FALSE)
# Reattach headers to cpr_data
names(cpr_dat) <- cpr_header
# Select relevant columns
cpr_dat <- cpr_dat |> 
  dplyr::select(`'Station'NA`, `'Year'NA`, `'Month'NA`,
                `'Day'NA`,
                `Latitude (degrees N)'NA`, `Longitude (degrees W)'NA`,
                contains("Calanus finmarchicus"),
                contains("Centropages typicus"),
                contains("'Pseudocalanus'")) |>
  dplyr::mutate(dataset = "CPR")
# Rename all columns
names(cpr_dat) <- c("station", "year", "month",
                    "day", 
                    "lat", "lon", "cfin_CI", 
                    "cfin_CII", "cfin_CIII", 
                    "cfin_CIV", "cfin_CV", "cfin_CVI", 
                    "cfin_CI_IV", "cfin_CV_VI", "ctyp_adult",
                    "ctyp_CIII", "ctyp_CIV", "ctyp_CV",
                    "ctyp_C", "ctyp_IV_V", "ctyp_IV_VI",
                    "ctyp_CVI", "ctyp_CV_CVI", "pseudo_adult",
                    "pseudo_CII", "pseudo_CV", "pseudo_C", 
                    "pseudo_CVI", "pseudo_CI_IV", "dataset")

# -------- Load NOAA data --------
# Read in data
NOAA1 <- readr::read_csv(file.path(fp_cpr, "NOAA_calanus_05103.csv"))
NOAA2 <- readr::read_csv(file.path(fp_cpr, "NOAA_calanus_05104.csv"))
# Bind datasets
NOAA <- rbind(NOAA1, NOAA2) |>
  # Select relevant columns
  dplyr::select(`#SHP-CRUISE`, YEAR, MON, DAY, LATITUDE, LONGITDE, UPPER_Z, `VALUE-per-volu`, `Taxa-Name`) |>
  # Select relevant taxa
  dplyr::filter(`Taxa-Name` == "Calanus finmarchicus" | `Taxa-Name` == "Centropages typicus" | `Taxa-Name` == "Pseudocalanus spp.")
# Isolate species and rename columns
cfin <- NOAA |> dplyr::filter(`Taxa-Name` == "Calanus finmarchicus") |>
  dplyr::rename(cfin_CV_VI = `VALUE-per-volu`)
ctyp <- NOAA |> dplyr::filter(`Taxa-Name` == "Centropages typicus") |>
  dplyr::rename(ctyp_adult = `VALUE-per-volu`)
pseudo <- NOAA |> dplyr::filter(`Taxa-Name` == "Pseudocalanus spp.") |>
  dplyr::rename(pseudo_adult = `VALUE-per-volu`)
# Join dataframes back together
NOAA <- dplyr::full_join(cfin, ctyp, by = c("#SHP-CRUISE", "YEAR", "MON", "DAY", "LATITUDE", "LONGITDE", "UPPER_Z")) |>
  dplyr::full_join(pseudo, by = c("#SHP-CRUISE", "YEAR", "MON", "DAY", "LATITUDE", "LONGITDE", "UPPER_Z")) |>
  dplyr::select(`#SHP-CRUISE`, YEAR, MON, DAY, LATITUDE, LONGITDE, cfin_CV_VI, ctyp_adult, pseudo_adult) |>
  dplyr::rename(station =`#SHP-CRUISE`, year = YEAR, month = MON, day = DAY, lat = LATITUDE, lon = LONGITDE) |>
  dplyr::mutate(cfin_CI = NA,
                cfin_CII = NA,
                cfin_CIII = NA,
                cfin_CIV = NA,
                cfin_CV = NA,
                cfin_CVI = NA,
                cfin_CI_IV = NA,
                ctyp_CIII = NA,
                ctyp_CIV = NA, 
                ctyp_CV = NA,
                ctyp_C = NA, 
                ctyp_IV_V = NA, 
                ctyp_IV_VI = NA,
                ctyp_CVI = NA,
                ctyp_CV_CVI = NA, 
                pseudo_CII = NA,
                pseudo_CV = NA, 
                pseudo_C = NA, 
                pseudo_CVI = NA, 
                pseudo_CI_IV = NA,
                dataset = "CPR")

# -------- Create database --------
# Combine individual datasets
database <- rbind(ecomon_dat, ecomon_staged_dat, mbon_dat_1, cpr_dat, NOAA) |>
  dplyr::filter(!is.na(lon))
# Replace missing values with NA
database[database == -9999] <- NA
# Define and correct incorrect longitudes
database$lon[database$lon >= 0] <- -database$lon[database$lon >= 0]
# Add column for total C. finmarchicus across all stages
database$cfin_total <- rowSums(database |> dplyr::select(contains("cfin")), na.rm = TRUE)
# Add column for total centropages across all stages
database$ctyp_total <- rowSums(database |> dplyr::select(contains("ctyp")), na.rm = TRUE)
# Add column for total pseudocalanus across all stages
database$pseudo_total <- rowSums(database |> dplyr::select(contains("pseudo")), na.rm = TRUE)
# Write database to csv for future use
write_csv(database, file.path(fp_db, "zooplankton_database.csv"))
  
