# Camille Ross
# June 16, 2020
# Purpose: Load in formatted yearly data and bind into one dataframe

#'@param fp <chr> filepath to formatted covariate data
#'@param years <seq> years of the data to bind together
bind_years <- function(fp, years) {
  # Load in first year
  full_data <- readr::read_csv(file.path(fp, paste0(min(years), ".csv")))
  # Loop through remaining years
  for (year in years[2:length(years)]) {
    # Load in data for given year
    temp_data <- readr::read_csv(file.path(fp, paste0(year, ".csv")))
    # Bind to complete dataset
    full_data <- rbind(full_data, temp_data)
  }
  # Return complete dataset
  return(full_data)
}