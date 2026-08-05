# Modeled after C Ross's 'test.R') but removes the yaml creation
#
# Provides a developer's false block for easy debugging.
#
# Modified buildZoopModel.R to change directory to `fp_out` before
# building out the model (which writes to the current directory)


 
source("buildZoopModel.R")


config_file = commandArgs(trailingOnly = TRUE)
if (length(config_file) < 1) {
  config_file = '/mnt/s1/projects/ecocast/projects/calanus/Versions/vtest.ben.nick/vtest.ben.nick.yaml'
}
if (!file.exists(config_file)) stop("config file not found: ", config_file)

# Read in parameters (a bit redundant, but makes it traceable, ideally YAML is written in separate file)
config <- yaml::read_yaml(config_file)

if (FALSE){
  version = "vtest.ben.nick"
  fp_md = "/mnt/s1/projects/ecocast/projects/calanus/calanus_data/Data/Databases/zooplankton_covar_data" 
  species = "ctyp"
  biomod_dataset = "ECOMON"
  fp_covars = "/mnt/s1/projects/ecocast/projectdata/calanus4whales/Env_Covars"
  env_covars = c("int_chl", "sst", "bat")
  years = 2003:2006
  fp_out = "/mnt/ecocast/projects/calanus/Versions/vtest.ben.nick"
  threshold = 0.9
  overwrite_proj = TRUE
  format_data = FALSE
  threshold_computed = 2063.294
}


if (!dir.exists(config$fp_out)) ok = dir.create(config$fp_out, 
                                                recursive = TRUE, 
                                                showWarnigns = FALSE)
threshold <- buildZoopModel(version = config$version, 
                            fp_md = config$fp_md, 
                            species = config$species, 
                            biomod_dataset = config$biomod_dataset, 
                            fp_covars = config$fp_covars, 
                            env_covars = config$env_covars, 
                            years = config$years, 
                            fp_out = config$fp_out, 
                            threshold = config$threshold, 
                            overwrite_proj = config$overwrite_proj,
                            format_data = config$format_data)

config$threshold_computed <- threshold
yaml::write_yaml(config, config_file)


# ---- TEST ----

# # File path to configuration files
# fp_config <- "../Versions"
# if (!dir.exists(fp_config)) {
#   dir.create(fp_config)
# }
# # # Whether to overwrite yaml file, if one already exists
# # overwrite <- TRUE
# # 
# # # Example parameters for test run
# # params <- list(
# #   version = "vtest.ben.nick",
# #   fp_md = "../calanus_data/Data/Databases/zooplankton_covar_data",
# #   species = "ctyp",
# #   biomod_dataset = "ECOMON",
# #   fp_covars = "../Env_Covars",
# #   env_covars = c("int_chl", "sst", "bat"),
# #   years = 2003:2006,
# #   fp_out = "../Models.Test.ben.nick",
# #   threshold = 0.9, # Threshold computed at 90th percentile
# #   overwrite_proj = FALSE,
# #   format_data = FALSE
# # )
# 
# # Write parameters to YAML file
# dir_version <- file.path(fp_config, params$version)
# filename <- file.path(dir_version, paste0(params$version, ".yaml"))
# 
# if (!dir.exists(dir_version) | overwrite) {
#   dir.create(dir_version, showWarnings = FALSE)
#   
#   if (!file.exists(filename) | overwrite) {
#     yaml::write_yaml(params, file.path(fp_config, params$version, paste0(params$version, ".yaml")))
#   }
# }
# 
# # Read in parameters (a bit redundant, but makes it traceable, ideally YAML is written in separate file)
# config <- yaml::read_yaml(filename)
# 
# if (FALSE){
#   version = config$version
#   fp_md = config$fp_md
#   species = config$species
#   biomod_dataset = config$biomod_dataset
#   fp_covars = config$fp_covars
#   env_covars = config$env_covars
#   years = config$years
#   fp_out = config$fp_out
#   threshold = config$threshold
#   overwrite_proj = config$overwrite_proj
#   format_data = config$format_data
# }
# 
# threshold <- buildZoopModel(version = config$version, 
#              fp_md = config$fp_md, 
#              species = config$species, 
#              biomod_dataset = config$biomod_dataset, 
#              fp_covars = config$fp_covars, 
#              env_covars = config$env_covars, 
#              years = config$years, 
#              fp_out = config$fp_out, 
#              threshold = config$threshold, 
#              overwrite_proj = config$overwrite_proj,
#              format_data = config$format_data)
# 
# # View threshold used
# threshold
# 
# # Save computed threshold (if using percentile method)
# if (threshold != params$threshold) {
#   params$threshold_computed <- threshold
#   yaml::write_yaml(params, file.path(fp_config, params$version, paste0(params$version, ".yaml")))
# }



