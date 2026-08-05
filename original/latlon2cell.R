# Camille Ross
# 9 June, 2020
# Purpose: Function to convert latitude and longitude values into pixels based on grid size
# Source: Dan Pendleton

#'@param lat <vec> column vector of original latitudes
#'@param lon <vec> column vector of original longitudes
#'@param cellsize_y <dbl> cell size of pixel in y direction
#'@param cellsize_x <dbl> cell size of pixel in x direction
latlon2cell <- function(lat,lon,cellsize_y, cellsize_x) {
  # %convert (lat lon) coordinates to (row column) coordinates
  # %lat=column vector containing latitude
  # %lon=column vector containing longitude
  # %ll_lat=lower left latitude
  # %ll_lon=lower left longitude
  # %cellsize=cell size in degrees
  
  # Compute longitude pixel
  COL=floor(((lon-(-72.46014))/cellsize_x))+1
  # Compute latitude pixel
  ROW=floor(((38.49874-lat)/cellsize_y))+1
  
  # Return longitude and latitude pixel values
  return(c(COL,ROW))
}