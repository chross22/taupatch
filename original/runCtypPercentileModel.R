# Camille H. Ross
# Nov. 7, 2023
# Purpose: Run model for C. typicus using percentile method

# --- Load required packages
require(yaml)

# --- Source files
source("buildZoopModel.R")

# ---- TEST ----

# File path to configuration files
fp_config <- "../Versions"
if (!dir.exists(fp_config)) {
  dir.create(fp_config)
}
# Whether to overwrite yaml file, if one already exists
overwrite <- FALSE

# Example parameters for test run
params <- list(
  version = "v0.9.7",
  fp_md = "../calanus_data/Data/Databases/zooplankton_covar_data",
  species = "ctyp",
  biomod_dataset = "ECOMON",
  fp_covars = "Env_Covars",
  env_covars = c("wind", "int_chl", "sst", "sst_grad", "jday", "uv_grad", "bat", "slope", "bots", "bott"),
  years = 2003:2017,
  fp_out = "../Models",
  threshold = 0.9, # Threshold computed at 90th percentile
  overwrite_proj = TRUE,
  format_data = FALSE
)

# Write parameters to YAML file
dir_version <- file.path(fp_config, params$version)
filename <- file.path(dir_version, paste0(params$version, ".yaml"))

if (!dir.exists(dir_version) | overwrite) {
  dir.create(dir_version, showWarnings = FALSE)
  
  if (!file.exists(filename) | overwrite) {
    yaml::write_yaml(params, file.path(fp_config, params$version, paste0(params$version, ".yaml")))
  }
}

# Read in parameters (a bit redundant, but makes it traceable, ideally YAML is written in separate file)
config <- yaml::read_yaml(filename)

threshold <- buildZoopModel(version = config$version, 
                            fp_md = config$fp_md, 
                            species = config$species, 
                            biomod_dataset = config$biomod_dataset, 
                            fp_covars = config$fp_covars, 
                            env_covars = config$env_covars, 
                            years = config$years, 
                            fp_out = config$fp_out, 
                            threshold = config$threshold, 
                            overwrite_proj = config$overwrite_proj
                            format_data = config$format_data)

# View threshold used
threshold

# Save computed threshold (if using percentile method)
if (threshold != params$threshold) {
  params$threshold_computed <- threshold
  yaml::write_yaml(params, file.path(fp_config, params$version, paste0(params$version, ".yaml")))
}



