# taupatch

Monthly spatial habitat suitability models for **high-abundance zooplankton
patches** ("tau-patches"), where a patch is any station whose abundance exceeds a
species-specific threshold.

Station data is matched to Copernicus Marine environmental covariates via
[`datamatch`](https://github.com/chross22/datamatch), optionally extended with
covariates derived from the covariate grid — gradients, fronts, lags, flow
diagnostics — via [`derivoce`](https://github.com/chross22/derivoce), classified
against the threshold, and modeled with a
[tidymodels](https://www.tidymodels.org) workflow.
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

Derived covariates (`covariates.derivoce`) additionally need:

```r
remotes::install_github("chross22/derivoce")
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
result$model$evaluation   # performance, with the cutoff each metric belongs to
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
generate_config("ctyp_shelf", active_species = "ctyp", years = c(2005, 2015),
                selected = c("SST", "SSS", "CHL"),
                transform = list(fourth_root = "CHL"))
```

Covariates are named the way the rest of the package names them, the file leads
with comments saying where those names come from, and it is loaded back and
validated before the path is returned — so a mistyped covariate is an error at
that call rather than five minutes into a run.

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
  transform:
    log1p: [CHL]
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
  transform:
    log1p: [CHL, DEPTH]
```

These replace the SRTM30 depth/slope layers the original used.

### Derived covariates

Gradients, fronts, lags, integrals, and flow diagnostics are computed rather than
downloaded, by [`derivoce`](https://github.com/chross22/derivoce). They go under
`covariates.derivoce` as a list of steps, each naming a derivoce function and the
arguments for it:

```yaml
covariates:
  selected: [SST, SSS, BOTT, CHL, UO, VO]
  bathymetry: [DEPTH]
  derivoce:
    - type: horizontal_gradient
      vars: [SST]              # SST_grad, degrees C per km
    - type: vertical_gradient
      surface: SST
      bottom: BOTT             # SST_BOTT_vgrad, the stratification index
    - type: lag_covariate
      vars: [CHL]
      n: 1                     # CHL_lag1
    - type: integrate_covariate
      vars: [CHL]
      window: year             # CHL_int, the original pipeline's int_chl
    - type: current_speed      # speed, the original pipeline's uv
    - type: horizontal_gradient
      vars: [speed]            # speed_grad, its uv_grad
    - distance_to_shore        # shore_dist, its dist
```

Steps run in order and see the columns earlier ones produced, which is why
`current_speed` followed by a gradient of `speed` works. `distance_to_front`,
`distance_to_contour`, `distance_to_isobath`, `ftle`, and `fsle` are available
too; `derivoce_covariates()` lists every step type with its units and the column
names it produces.

These are computed **on the covariate grid, before stations are matched to it** —
a gradient or a front is a property of the field, and scattered station points
cannot recover one. After that they are ordinary covariate columns: matched to
stations, carried onto the projection grid, and picked up as predictors
automatically, and `covariates.transform` can name them.

Three things cost data, and a run says so when they happen:

- Lags, integrals, and temporal gradients are undefined in the first month of the
  record. Stations there are dropped, and that month's projection is skipped.
- Neighbourhood steps — gradients, fronts, Lyapunov exponents — are undefined on
  the edge of the study area, so its border is lost from both the training
  stations and the maps. Draw the bounding box wider than the stations.
- A neighbourhood step reading an upsampled variable warns, for the reason below.

### Transformations

Each covariate takes at most one transform, named under `covariates.transform`:

```yaml
covariates:
  transform:
    log1p: [CHL, DEPTH]     # log(1 + |x|) - the default, defined at zero
    fourth_root: [NO3]
    yeojohnson: [SST_tgrad]
  normalize: true           # centre and scale; on unless turned off
```

| Name | What it is |
|---|---|
| `log1p` | `log(1 + \|x\|)`. Defined at zero, which the plain logs are not |
| `log` / `log10` | Natural and base-10 log of the magnitude |
| `sqrt` / `fourth_root` | Milder compression, defined at zero; fourth root is the plankton standard |
| `boxcox` | Estimates the best power per covariate; needs strictly positive input |
| `yeojohnson` | Box-Cox extended to zero and negative values |

Two rules the package enforces against the data rather than trusting:

- **`log` and `log10` are undefined at zero**, and zeros are ordinary in
  chlorophyll and in any derived integral that starts there. Asking for one on a
  column containing zeros is an error pointing at `log1p`.
- **The log and root family takes `abs(x)` first.** That is right for a magnitude
  stored with a sign convention — depth is negative — and wrong for a genuinely
  signed covariate, where it maps `-2` and `2` onto the same predictor. Derived
  covariates make this common: temporal gradients, vertical gradients, and
  current components are all signed. Those columns warn, and `yeojohnson` is the
  transform that handles them properly.

`covariate_transforms()` lists all of them. `covariates.log_transform` still works
and still means `log1p`.

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

### Reading the evaluation

`evals.csv` names the cutoff each metric belongs to, because the answer changes
a lot with it:

| metric | threshold | value |
|---|---|---|
| roc_auc | | 0.876 |
| pr_auc | | 0.433 |
| sens | 0.500 | 0.261 |
| spec | 0.500 | 0.977 |
| tss | 0.500 | 0.238 |
| sens | 0.074 | 0.870 |
| spec | 0.074 | 0.767 |
| tss | 0.074 | 0.637 |

Two things this makes visible that a single-column table hides:

- **0.5 is the wrong cutoff here.** With only a tenth of stations patches, a
  random forest at 0.5 calls almost nothing a patch — sensitivity 0.26 against
  0.87 at the TSS-optimal cutoff. The model is far better than the default
  numbers suggest. Use `classification_threshold` from `threshold.yaml` when
  binarising a projection, which is what the original was reaching for with
  biomod2's `metric.binary = 'ROC'`.
- **ROC AUC flatters an imbalanced problem.** 0.876 looks strong, but PR AUC is
  0.433 — because ROC's false-positive rate has the large non-patch class in its
  denominator. Precision is the question a patch map actually poses, and the
  trade-off is real: moving to the optimal cutoff raises sensitivity to 0.87 but
  drops precision to 0.30.

`diagnostics/` holds the curves these come from, and `cv_predictions.csv` the
held-out predictions, so any metric not tabulated here can be computed without
refitting.

## Outputs

Each run writes to `paths.output_dir`:

```
model.rds              fitted tidymodels workflow
evals.csv              performance, stating the cutoff each metric belongs to
cv_metrics.csv         the raw per-fold resampling table
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
R/bathymetry.R          bathymetry_covariates(), the static seafloor layers
R/derivoce.R            derivoce_covariates(), add_derivoce_covariates()
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
