# Camille Ross
# June 1, 2020
# Purpose: Map individual Calanus datasets to understand data extent

# -------- Load libraries --------
library(readr)
library(raster)
library(dplyr)
library(ggplot2)
library(lubridate)
library(rnaturalearth)
library(rnaturalearthdata)

# -------- Initialize filepaths --------
# Data filepath
fp_data <- "./calanus_data/Data"
# ECOMON filepath
fp_ecomon <- file.path(fp_data, "ECOMON")
# Runge filepath
fp_runge <- file.path(fp_data, "Runge")
# CPR filepath
fp_cpr <- file.path(fp_data, "CPR")
# Database filepath
fp_db <- file.path(fp_data, "Databases")

# -------- Map ECOMON data ---------
# Read in data -- version 3.5
ecomon_dat <- readr::read_csv(file.path(fp_ecomon, "EcoMon_Plankton_Data_v3_5.csv")) %>%
  mutate(year = lubridate::year(as.Date(date, format='%d-%b-%y')),
         month = lubridate::month(as.Date(date, format='%d-%b-%y')),
         day = lubridate::day(as.Date(date, format='%d-%b-%y')))

# Plot each month
for (i in 1:12) {
  ggplot(ecomon_dat %>% filter(month == i), aes(x = lon, y = lat, color = calfin_10m2)) + 
    geom_point() +
    ggtitle(i)
}

# -------- Map Runge data --------
# Read in data
runge_dat <- readr::read_csv(file.path(fp_runge, "UBER_ZOOBIO_2012_Aug16_2017_edit4GAMM.csv")) %>%
  mutate(year = YEAR,
         month = MNTH,
         day = DAY)

# Plot data using ggplot
for (i in 1:12) {
  ggplot(runge_dat %>% filter(month == i), aes(x = `Log Decimal`, y = `Lat Decimal`, color = `Calanus_finmarchicusCV(M2)`)) +
      geom_point() +
      ggtitle(i)
}

# -------- Map CPR data --------
# Read in headers
cpr_header <- readr::read_csv(file.path(fp_cpr, "GOMCPR_trim_cop.csv"), n_max = 2, col_names = FALSE)
# Concatonate fist and second row of headers
cpr_header <- paste0(cpr_header[1,], cpr_header[2,])
# Read in data
cpr_dat <- readr::read_csv(file.path(fp_cpr, "GOMCPR_trim_cop.csv"), skip = 2, col_names = FALSE)
# Reattach headers to cpr_data
names(cpr_dat) <- cpr_header
# Rename first few columns
cpr_dat <- cpr_dat %>% dplyr::rename(station = `'Station'NA`,
                                     year = `'Year'NA`,
                                     month = `'Month'NA`,
                                     day = `'Day'NA`,
                                     hour = `'Hour'NA`,
                                     minute = `'Minute'NA`,
                                     lat = `Latitude (degrees N)'NA`,
                                     lon = `Longitude (degrees W)'NA`)

# Plot data using ggplot
for (i in 1:12) {
  ggplot(cpr_dat %>% filter(month == i), aes(x = -lon, y = lat, color = `'Calanus finmarchicus''copepodite V-VI'`)) +
    geom_point() +
    ggtitle(i)
}

# -------- Plot database data --------
# Read in database
db_dat <- readr::read_csv(file.path(fp_db, "zooplankton_database.csv")) %>% 
  dplyr::filter(year >= 2000) 
# Fix longitudes for consitency
db_dat$lon[db_dat$lon >= 0] <- -db_dat$lon[db_dat$lon >= 0]
# Take the log of the count to get log abundance
db_dat$abund <- log1p(db_dat$cfin_total)
# Load map data
world <- ne_countries(scale = "medium", returnclass = "sf")
# Plot C. finmarchicus data
ggplot(data = world) +
  geom_sf() +
  coord_sf(xlim = c(min(db_dat$lon) - 0.5, max(db_dat$lon) + 0.5), 
           ylim = c(min(db_dat$lat) - 0.5, max(db_dat$lat)) + 0.5, expand = FALSE) +
  geom_point(data = db_dat, mapping = aes(x = lon, y = lat, color = abund), cex = 0.2) +
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
        panel.background = element_blank())

