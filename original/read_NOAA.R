# Camille Ross
# 30 June, 2020
# Purpose: parse NOAA calanus data

# Load libraries
library(readr)
library(dplyr)

# Function to parse NOAA calanus data
#'@param fp_data <chr> file path to the folder containing the short format data files in .csv format
#'@param fp_out <chr> file path to the output directory including the output file name
#'@return full_data <dataframe> formatted NOAA data
read_NOAA <- function(fp_data = "./calanus_data/Data/NOAA_PR/copepod__us-05104/data_src/short-format",
                      fp_out = "./calanus_data/Data/NOAA_CPR/NOAA_calanus_05104.csv",
                      to_csv = TRUE) {
  
  # Retrieve filenames
  filenames <- list.files(fp_data)
  
  # Initialize object to store data
  full_data <- data.frame()
  
  # Loop through files
  for (file in filenames) {
    # Check that file is a CSV
    if (grepl(".csv", file, fixed = TRUE)) {
      # Read in headers
      headers <- readr::read_csv(file.path(fp_data, file), col_names = FALSE, skip = 15, n_max = 1)
      # Read in data
      dat <- readr::read_csv(file.path(fp_data, file), col_names = FALSE, skip = 17)
      # Reattach headers to data
      names(dat) <- headers
      # Remove NA column
      drops <- c("NA")
      dat <- dat[,!(names(dat) %in% drops)]
      # Bind file to full dataset
      full_data <- rbind(full_data, dat)
    }
  }
  # Write to csv
  if (to_csv) {
    readr::write_csv(x = full_data, path = fp_out)
  }
  # Return formatted data
  return(full_data)
}