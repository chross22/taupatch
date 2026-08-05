# A script to check for required packages, install any missing, and then load

# packages from CRAN
CRAN = c("raster", "dplyr", "readr", "raster", "sf",
         "viridis", "Metrics", "mapdata", "maps", "ggplot2",
         "stats", "biomod2", "ff", "yaml", "remotes")

# packages from github (or gitlab, etc)         
GITHUB = character()
       
# get the names of the currently installed
ip = installed.packages() |> rownames()         
        
# install missing
for (cran in CRAN){
  if (!(cran %in% ip)) install.packages(cran)
}

# install missing from github
for (github in GITHUB){
  if (!(github %in% GITHUB)) remotes::install_github(github)
}

# source the functions
for (p in c(CRAN, GITHUB)) library(p, character.only = TRUE)