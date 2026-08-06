# taupatch

Monthly spatial habitat suitability models for **high-abundance zooplankton
patches** ("tau-patches"), where a patch is any station whose abundance exceeds a
species-specific threshold.

Station data is matched to Copernicus Marine environmental covariates via
[`datamatch`](https://github.com/chross22/datamatch), classified against the
threshold, and modeled with a [tidymodels](https://www.tidymodels.org) workflow.
The fitted model is then projected to a habitat suitability map for every
configured month.

Rebuilt from the `biomod2` pipeline of Ross et al. (2023), which is preserved
unmodified in [`original/`](original/). Species, life stages, covariates,
thresholds, study area, and model settings are all driven by a YAML config
rather than by editing code — see [`docs/rebuild_plan.md`](docs/rebuild_plan.md)
for what changed and why.

## Installation

```r
# install.packages("remotes")
remotes::install_github("chross22/taupatch")
```

Environmental data needs the [Copernicus Marine
Toolbox](https://help.marine.copernicus.eu/en/collections/4060068-copernicus-marine-toolbox)
installed and configured with your Copernicus credentials, plus:

```r
remotes::install_github("BigelowLab/copernicus")
remotes::install_github("chross22/datamatch")
```

The Shiny app additionally needs `shiny` and `leaflet`.

## Try it without any data

The pipeline runs end-to-end on synthetic data, with no Copernicus credentials
and no network access:

```r
library(taupatch)
run_taupatch_app()
```

Or headless:

```r
config <- load_config(system.file("configs/mock_test.yaml", package = "taupatch"))
config$paths$zoop_file <- file.path(tempdir(), "mock.csv")
config$paths$output_dir <- file.path(tempdir(), "out")
generate_mock_zoop_data(config)

result <- run_taupatch(config)
result$model$metrics      # cross-validated ROC AUC, kappa, sensitivity, specificity, TSS
result$model$importance   # permutation variable importance
result$projections        # one GeoTIFF + PNG per projected month
```

The mock data plants a latitudinal gradient and a seasonal cycle into both
abundance and the covariates, so a working pipeline scores well above chance —
a smoke test that passed on noise would not be testing anything.

## Running on real data

The zooplankton database is not included and should not be committed (`data/` is
gitignored). Point a config at your local copy of the CSV that
[`original/create_database.R`](original/create_database.R) writes:

```r
config <- load_config("inst/configs/cfin_gom.yaml")   # edit paths.zoop_file first
result <- run_taupatch(config)
```

`inst/configs/cfin_gom.yaml` is a documented example — *Calanus finmarchicus* from
ECOMON stations with monthly Copernicus physical covariates. Generate new configs
programmatically rather than hand-editing YAML:

```r
generate_config("cfin_gom", active_species = "cfin", years = c(2005, 2015))
```

## Configuration

### Species and life stages

Each species names the prefix of its columns in the database. `column_prefix`
defaults to the species key, so only an aliased name needs it — `pcal` is the one
case, since its columns are `pseudo_*`:

```yaml
species:
  active: cfin
  catalog:
    cfin:
      threshold: {type: percentile, value: 0.9}
    pcal:
      column_prefix: pseudo
      threshold: {type: percentile, value: 0.9}
```

`stages` optionally narrows to particular life stages, which are summed:

```yaml
    cfin:
      stages: [CV, adult]
```

Which stages exist differs by species, so read them off the data rather than
assuming:

```r
available_stages("data/zooplankton_database.csv", "cfin")
#> "CI" "CII" "CIII" "CIV" "CV" "CVI" "adult"
```

Only individually resolved stages are selectable. The database also holds
columns spanning several stages (`ctyp_CV_CVI`, `pseudo_CI_IV`, ...), which
overlap the single stages and would double-count if mixed with them. Two
consequences worth knowing:

- **`cfin_CV_VI` is offered as `adult`.** ECOMON does not resolve CV from CVI for
  *C. finmarchicus* and reports the combined count, which is the adult number.
  Selecting `adult` together with `CV` or `CVI` is rejected as double-counting.
- **Leaving `stages` empty sums every column**, combination columns included,
  reproducing `<prefix>_total`. This is what keeps a default ECOMON run working.

### Thresholds

A patch is a station at or above the threshold, given either as a percentile of
the observed distribution or as an absolute abundance:

```yaml
threshold: {type: percentile, value: 0.9}   # top 10% of stations
threshold: {type: absolute, value: 2063.3}  # individuals/m2
```

The type is explicit because the original inferred it from whether the value was
below 1, which silently misreads any real threshold under 1. Each run writes the
computed threshold to `threshold.yaml`, so a percentile run can be reproduced as
an absolute one.

### Covariates

Covariates are named the way people refer to them and resolve to a Copernicus
product, dataset, and variable. Those sharing a dataset are fetched in one
request:

```yaml
covariates:
  selected: [SST, SSS, BOTT, MLD, CHL]
  derived: [jday]
  log_transform: [CHL]
```

```r
covariate_info()[, c("name", "label", "units")]
```

| Name | Long name | Units |
|---|---|---|
| SST | Sea surface temperature | degrees C |
| SSS | Sea surface salinity | PSU |
| BOTT | Bottom temperature | degrees C |
| UO / VO | Eastward / northward current velocity | m/s |
| SSH | Sea surface height | m |
| MLD | Mixed layer depth | m |
| CHL | Chlorophyll-a concentration | mg/m3 |
| NO3 | Nitrate concentration | mmol/m3 |
| O2 | Dissolved oxygen | mmol/m3 |
| DEPTH / SLOPE / ASPECT | Seafloor depth, slope, aspect (static) | m, degrees |
| jday | Day of year (derived) | day (1–366) |

`jday` is what lets one pooled model produce month-specific maps instead of
requiring twelve separate models.

**Seafloor covariates are static** — they don't vary by month, so they're
downloaded once from NOAA ETOPO via `marmap::getNOAA.bathy()` and attached to
every time step. They go under their own config key, since they don't come from
Copernicus:

```yaml
covariates:
  selected: [SST, SSS, CHL]     # Copernicus, time-varying
  bathymetry: [DEPTH, SLOPE]    # NOAA ETOPO, static
  log_transform: [CHL, DEPTH]
```

These replace the SRTM30 depth/slope/distance-to-shore layers the original used.
Distance to shore, gradients, time-integrals and lags are not here — those are
derived quantities headed for a separate package.

### Combining products of different resolution

Copernicus products do not share a grid — physics is 0.083 degrees,
biogeochemistry 0.25 — so selecting `SST` and `CHL` together means two grids that
have to be reconciled onto one. `covariates.grid` decides which:

```yaml
covariates:
  selected: [SST, SSS, CHL]
  grid: finest      # or: coarsest
```

- **`finest`** (the default) keeps the finest grid and repeats each coarse cell's
  value across the fine cells inside it. Fine-scale structure survives in the fine
  variables, which matters because fronts and gradients are computed from them.
- **`coarsest`** joins onto the coarsest grid, so no value is ever replicated.

The cost of `finest` is worth stating plainly: **a coarse variable rendered on a
fine grid is blocky, not detailed.** Its values are constant within each original
cell and step at the boundaries, so a spatial gradient computed from an upsampled
variable is an artifact — zero inside each block, spiking at edges that belong to
the source grid rather than the ocean. Compute gradients from variables at their
native resolution.

A run reports which covariates were upsampled, and records them on the result as
an `upsampled` attribute.

### Training and projection windows

These are separate, since fitting on a long history and projecting a shorter or
later period is the normal case. Covariates are fetched for the union of the two:

```yaml
dates:                        # observations the model is fitted on
  years: [2003, 2017]
  months: [1, 12]
projection:                   # months that get mapped; omit to reuse the above
  years: [2018, 2020]
  months: [1, 12]
```

## The app

```r
run_taupatch_app()                              # synthetic data
run_taupatch_app("inst/configs/cfin_gom.yaml")  # your own config
```

Pick a species, life stages, threshold, windows, study area, and covariates, then
run the model. Tabs:

- **Config** — the exact YAML a run would use, so anything done in the GUI is
  reproducible from a config file
- **Covariates** — every covariate's units, long name, and source dataset; click
  one for its full definition
- **Results** — cross-validated metrics, variable importance, threshold used
- **Maps** — monthly suitability on a leaflet basemap, plus a button to download
  the whole projection stack as a zip of `<year>-<month>.tiff` files
- **Covariate trends** — month-by-year heatmap of each covariate's study-area
  mean, which makes the seasonal cycle read down a column and gaps in the record
  show up as blank cells
- **Log** — stage-by-stage output from the run

## Outputs

Each run writes to `paths.output_dir`:

```
model.rds              fitted tidymodels workflow
evals.csv              cross-validated ROC AUC, kappa, sensitivity, specificity, TSS
var_importance.csv     permutation variable importance
var_importance.png
threshold.yaml         the abundance threshold actually used
projections/<species>_<year>_<month>.tif
plots/<species>_<year>_<month>.png
covariates/monthly_means.csv       study-area mean per covariate, month, and year
covariates/<covariate>_heatmap.png month-by-year heatmap
bathymetry/                        marmap's cached NOAA download, if used
```

## Repository layout

```
R/config.R              load_config(), generate_config()
R/zoop_data.R           load_zoop_data(), label_patch(), available_stages()
R/covariate_catalog.R   copernicus_covariates(), covariate_info()
R/covariates.R          fetch_covariates(), attach_covariates(), covariate_grid()
R/model.R               fit_patch_model()
R/project.R             project_patch_model()
R/plotting.R            plot_projection(), plot_importance()
R/pipeline.R            run_taupatch()
R/mock.R                synthetic data, for testing without the real database
R/app.R                 run_taupatch_app()
inst/configs/           example run configs
inst/shiny/             the app
original/               the pre-rebuild biomod2 pipeline, archived unmodified
docs/rebuild_plan.md    what changed from original/ and why
```

## Citation

Ross et al. (2023).
