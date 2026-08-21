# Covariate reference table

The catalog as a data frame, for display in documentation or the app's
covariate reference tab.

## Usage

``` r
covariate_info(include_derived = TRUE)
```

## Arguments

- include_derived:

  also describe covariates computed by the pipeline rather than fetched

## Value

a data frame with `name`, `label`, `units`, `variable`, `dataset`,
`spatial`, `temporal`, and `description` columns

## Examples

``` r
covariate_info()[, c("name", "label", "units")]
#>                   name                                   label
#> 1                  SST                 Sea surface temperature
#> 2                  SSS                    Sea surface salinity
#> 3                 BOTT                      Bottom temperature
#> 4                 BOTS                         Bottom salinity
#> 5                   UO               Eastward current velocity
#> 6                   VO              Northward current velocity
#> 7                  SSH                      Sea surface height
#> 8                  MLD                       Mixed layer depth
#> 9                  SIC                   Sea ice concentration
#> 10                 CHL Chlorophyll-a concentration (satellite)
#> 11                  PP          Primary production (satellite)
#> 12               DIATO      Diatom chlorophyll-a concentration
#> 13                DINO   Dinophyte chlorophyll-a concentration
#> 14                 NO3                   Nitrate concentration
#> 15                 PO4                 Phosphate concentration
#> 16                  O2                        Dissolved oxygen
#> 17                  PH                                      pH
#> 18           CHL_MODEL     Chlorophyll-a concentration (model)
#> 19           NPP_MODEL          Net primary production (model)
#> 20                WSPD                              Wind speed
#> 21                UWND                           Eastward wind
#> 22                VWND                          Northward wind
#> 23                TAUX                    Eastward wind stress
#> 24                TAUY                   Northward wind stress
#> 25                 TAU                   Wind stress magnitude
#> 26               DEPTH                             Water depth
#> 27               SLOPE                            Bottom slope
#> 28              ASPECT                           Bottom aspect
#> 29                 TPI              Topographic position index
#> 30                jday                             Day of year
#> 31 horizontal_gradient                     Horizontal gradient
#> 32   vertical_gradient                       Vertical gradient
#> 33   temporal_gradient                       Temporal gradient
#> 34       lag_covariate                        Lagged covariate
#> 35 integrate_covariate                    Integrated covariate
#> 36       current_speed                           Current speed
#> 37                 eke                     Eddy kinetic energy
#> 38                ftle           Finite-time Lyapunov exponent
#> 39                fsle           Finite-size Lyapunov exponent
#> 40   distance_to_front                       Distance to front
#> 41 distance_to_contour                   Distance to a contour
#> 42 distance_to_isobath                     Distance to isobath
#> 43   distance_to_shore                       Distance to shore
#>                                           units
#> 1                                     degrees C
#> 2                                           PSU
#> 3                                     degrees C
#> 4                                           PSU
#> 5                                           m/s
#> 6                                           m/s
#> 7                                             m
#> 8                                             m
#> 9                                      fraction
#> 10                                        mg/m3
#> 11                                    mg/m2/day
#> 12                                        mg/m3
#> 13                                        mg/m3
#> 14                                      mmol/m3
#> 15                                      mmol/m3
#> 16                                      mmol/m3
#> 17                                     unitless
#> 18                                        mg/m3
#> 19                                    mg/m3/day
#> 20                                          m/s
#> 21                                          m/s
#> 22                                          m/s
#> 23                                         N/m2
#> 24                                         N/m2
#> 25                                         N/m2
#> 26                                            m
#> 27                                      degrees
#> 28                                      degrees
#> 29                                            m
#> 30                                  day (1-366)
#> 31                          source units per km
#> 32 source units, or per m when `depth` is given
#> 33         source units per step, day, or month
#> 34                                 source units
#> 35    source units, accumulated over the window
#> 36                                          m/s
#> 37                                        m2/s2
#> 38                              day^-1 (a rate)
#> 39                              day^-1 (a rate)
#> 40                                           km
#> 41                                           km
#> 42                                           km
#> 43                                           km
covariate_info()[, c("name", "spatial", "temporal")]
#>                   name                    spatial        temporal
#> 1                  SST             0.083° (~9 km)         monthly
#> 2                  SSS             0.083° (~9 km)         monthly
#> 3                 BOTT             0.083° (~9 km)         monthly
#> 4                 BOTS             0.083° (~9 km)         monthly
#> 5                   UO             0.083° (~9 km)         monthly
#> 6                   VO             0.083° (~9 km)         monthly
#> 7                  SSH             0.083° (~9 km)         monthly
#> 8                  MLD             0.083° (~9 km)         monthly
#> 9                  SIC             0.083° (~9 km)         monthly
#> 10                 CHL             4 km (~0.036°)         monthly
#> 11                  PP             4 km (~0.036°)         monthly
#> 12               DIATO             4 km (~0.036°)         monthly
#> 13                DINO             4 km (~0.036°)         monthly
#> 14                 NO3             0.25° (~28 km)         monthly
#> 15                 PO4             0.25° (~28 km)         monthly
#> 16                  O2             0.25° (~28 km)         monthly
#> 17                  PH             0.25° (~28 km)         monthly
#> 18           CHL_MODEL             0.25° (~28 km)         monthly
#> 19           NPP_MODEL             0.25° (~28 km)         monthly
#> 20                WSPD                    unknown         monthly
#> 21                UWND                    unknown         monthly
#> 22                VWND                    unknown         monthly
#> 23                TAUX                    unknown         monthly
#> 24                TAUY                    unknown         monthly
#> 25                 TAU                    unknown         monthly
#> 26               DEPTH 4 arc-min (~7 km), default          static
#> 27               SLOPE 4 arc-min (~7 km), default          static
#> 28              ASPECT 4 arc-min (~7 km), default          static
#> 29                 TPI 4 arc-min (~7 km), default          static
#> 30                jday                        n/a per observation
#> 31 horizontal_gradient              as its inputs   as its inputs
#> 32   vertical_gradient              as its inputs   as its inputs
#> 33   temporal_gradient              as its inputs   as its inputs
#> 34       lag_covariate              as its inputs   as its inputs
#> 35 integrate_covariate              as its inputs   as its inputs
#> 36       current_speed              as its inputs   as its inputs
#> 37                 eke              as its inputs   as its inputs
#> 38                ftle              as its inputs   as its inputs
#> 39                fsle              as its inputs   as its inputs
#> 40   distance_to_front              as its inputs   as its inputs
#> 41 distance_to_contour              as its inputs   as its inputs
#> 42 distance_to_isobath              as its inputs   as its inputs
#> 43   distance_to_shore              as its inputs   as its inputs
```
