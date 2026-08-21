# Write a taupatch run config

Defaults reproduce a working ECOMON run over the Northeast US shelf, so
a new config is normally one call with a name. The default bounding box
matches the extent the original pipeline cropped its projections to
(`original/load_covars.R:147`).

## Usage

``` r
generate_config(
  name,
  zoop_file = "data/zooplankton_database.csv",
  output_dir = file.path("output", name),
  species = default_species_catalog(),
  active_species = "cfin",
  years = c(2003, 2017),
  months = c(1, 12),
  bbox = list(xmin = -76, xmax = -65, ymin = 35, ymax = 45),
  covariate_source = "copernicus",
  selected = c("SST", "SSS", "BOTT", "MLD", "CHL"),
  bathymetry = c("DEPTH", "SLOPE"),
  prejoin = list(),
  climate = character(),
  derivoce = list(),
  transform = list(log1p = c("CHL", "DEPTH")),
  normalize = TRUE,
  type = "rf",
  trees = 500,
  cv_folds = 10,
  dir = "inst/configs"
)
```

## Arguments

- name:

  config name; the file is written to `<dir>/<name>.yaml`

- zoop_file:

  path to the zooplankton database CSV

- output_dir:

  where run outputs are written

- species:

  named list of species definitions; defaults to the three taxa in the
  original database (`cfin`, `ctyp`, `pseudo`) at the 90th percentile

- active_species:

  which species to model

- years:

  two-element `c(start, end)` year range

- months:

  two-element `c(start, end)` month range

- bbox:

  named list with `xmin`/`xmax`/`ymin`/`ymax`

- covariate_source:

  one of `"copernicus"`, `"local_netcdf"`, `"mock"`

- selected:

  time-varying covariate names; see
  [`copernicus_covariates()`](https://camilleross.org/taupatch/reference/copernicus_covariates.md)

- bathymetry:

  static seafloor covariate names; see
  [`bathymetry_covariates()`](https://camilleross.org/taupatch/reference/bathymetry_covariates.md)

- prejoin:

  list of per-covariate steps applied before products are joined; see
  [`prejoin_steps()`](https://camilleross.org/taupatch/reference/prejoin_steps.md)

- climate:

  climate index names; see
  [`climate_index_covariates()`](https://camilleross.org/taupatch/reference/climate_index_covariates.md)

- derivoce:

  list of derived-covariate steps; see
  [`derivoce_covariates()`](https://camilleross.org/taupatch/reference/derivoce_covariates.md)

- transform:

  named list of transform to covariate names; see
  [`covariate_transforms()`](https://camilleross.org/taupatch/reference/covariate_transforms.md)

- normalize:

  whether to center and scale the predictors

- type:

  which model to fit; see
  [`model_types()`](https://camilleross.org/taupatch/reference/model_types.md)

- trees:

  number of trees in the random forest

- cv_folds:

  number of cross-validation folds

- dir:

  directory to write the config into

## Value

the path written, invisibly

## Details

Covariates are named the way the rest of the package names them — `SST`,
not `thetao` on `cmems_mod_glo_phy_my_0.083deg_P1M-m` — so a generated
config reads like the shipped example and can be edited without
consulting the Copernicus catalog.
[`covariate_info()`](https://camilleross.org/taupatch/reference/covariate_info.md)
lists the names; the raw `covariates.copernicus` block is still accepted
by hand for a dataset the catalog does not cover.

The file is loaded back and validated before the path is returned, so a
mistyped covariate or transform is an error now rather than five minutes
into a run.

## See also

[`covariate_info()`](https://camilleross.org/taupatch/reference/covariate_info.md)
for the covariate names,
[`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)
to read the result back

## Examples

``` r
if (FALSE) { # \dontrun{
generate_config("cfin_gom")
generate_config("ctyp_shelf", active_species = "ctyp",
                selected = c("SST", "SSS", "CHL"),
                transform = list(fourth_root = "CHL"))
} # }
```
