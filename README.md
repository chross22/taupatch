# taupatch

<!-- badges: start -->
[![R-CMD-check](https://github.com/chross22/taupatch/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/chross22/taupatch/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

Monthly spatial habitat suitability models for **high-abundance zooplankton
patches** ("tau-patches"), where a patch is any station whose abundance exceeds a
species-specific threshold.

Station data is matched to Copernicus Marine environmental covariates with
[`datamatch`](https://github.com/chross22/datamatch). You can add covariates
derived from that grid with [`derivoce`](https://github.com/chross22/derivoce):
gradients, fronts, lags, and flow diagnostics. Stations are then classified
against the abundance threshold and modeled with a
[tidymodels](https://www.tidymodels.org) workflow (Kuhn & Wickham 2020). The
fitted model is projected to a habitat suitability map for every month you
configure — a presence/absence species distribution model in the sense of Elith
& Leathwick (2009), where "presence" is a patch rather than an animal.

This is the model from [Ross et al.
(2023)](https://doi.org/10.3354/meps14204), *Estimating North Atlantic right
whale prey based on* Calanus finmarchicus *thresholds*, rebuilt as an R package.
The original `biomod2` pipeline (Thuiller et al. 2009) is kept unmodified in
[`original/`](original/).

Species, life stages, covariates, thresholds, study area, and model settings all
come from a YAML config now, rather than from editing code. See
[`docs/rebuild_plan.md`](docs/rebuild_plan.md) for what changed and why.

**If you publish from a run, cite the data and methods that run actually used.**
The [reference list](vignettes/taupatch.Rmd) is grouped so you can pick out
exactly those, and each function's own `?help` carries the references relevant to
it.

## Run it without writing code

The whole model runs from a GUI. Point it at a station CSV, pick a species and a
threshold, choose covariates, press Run — no config file and no R beyond the one
line that starts it.

```r
install.packages("remotes")
remotes::install_github("chross22/taupatch")
taupatch::run_taupatch_app()
```

That opens on synthetic data, so it works before you have Copernicus credentials
or a station database. To model your own, put its path in the sidebar: the file
is read where it already is and never copied, a raw NEFSC export is reshaped for
you, and the columns are checked before a run starts rather than partway through
one.

Everything is a control rather than a config field — species, life stages,
threshold, windows, study area, covariates, derived covariates, transforms, model
type. Press **Download config** and the run you clicked your way to becomes a
YAML file you can re-run or hand to someone else.

Tabs run in the order the questions come up: **Config** (the exact YAML, updating
as you click), **Zooplankton data** (the stations before any model touches them),
**Covariate trends** (each covariate's mean by month and year, and the field
itself), **Results**, **Diagnostics** (ROC, precision-recall, calibration,
partial effects), **Maps**, **Log** (including how many cells each month lost and
to which covariate), and a **Covariate dictionary**.

The Shiny app needs `shiny`, `leaflet`, and `shinyFiles`.

## Installation

```r
# install.packages("remotes")
remotes::install_github("chross22/taupatch")
```

**To get the vignettes, ask for them.** `install_github()` does not build them by
default, so `vignette("taupatch")` finds nothing after a plain install. That is
the install being economical, not the vignette being missing:

```r
remotes::install_github("chross22/taupatch", build_vignettes = TRUE)
```

Building needs `knitr` and `rmarkdown`, and the getting-started vignette runs the
whole pipeline on mock data as it renders, so expect a minute rather than a
moment.

Environmental data needs the [Copernicus Marine
Toolbox](https://help.marine.copernicus.eu/en/collections/4060068-copernicus-marine-toolbox)
(EU Copernicus Marine Service 2025) installed and configured with your Copernicus
credentials, plus:

```r
remotes::install_github("chross22/datamatch")
remotes::install_github("chross22/derivoce")   # only for covariates.derivoce
```

`fancyfx` draws the effect and uncertainty figures and is installed with the
package from the `Remotes` field, so it needs no separate step.

## Try it without any data

The app opens on synthetic data, and so does the **[getting started
vignette](vignettes/taupatch.Rmd)**, which walks one complete run — fit,
evaluate, project, read the maps:

```r
vignette("taupatch")
```

The same run headless, with no Copernicus credentials and no network access:

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
abundance and the covariates, so a working pipeline scores well above chance. A
smoke test that passed on noise would not be testing anything.

## Running on real data

If you have the raw ECOMON export rather than a formatted database, build one
first. That export is NOAA's Ecosystem Monitoring plankton dataset (NOAA NEFSC,
NCEI Accession 0187513), which is not distributed with this package and carries
its own citation:

```r
formatted <- format_zoop_data("raw_ecomon.csv", write_to = "data/zooplankton.csv")
zoop_taxa("raw_ecomon.csv")     # every taxon the file carries
```

It splits `DATE` into year, month and day, renames `LATITUDE`/`LONGITUDE`, and
strips the units off each taxon column, so `CALANUS_FINMARCHICUS_10M2` becomes
`CALANUS_FINMARCHICUS`. Life stages, where a dataset resolves them, are kept
(`CALANUS_FINMARCHICUS_CV`) — the form `column_prefix` and `stages` match.

`species_catalog_from()` writes the matching `species.catalog`, giving each taxon
whichever form its columns support:

```r
generate_config("my_run", zoop_file = "data/zooplankton.csv",
                species = species_catalog_from("raw_ecomon.csv",
                                               aliases = c(cfin = "CALANUS_FINMARCHICUS")))
```

The zooplankton database is not included and should not be committed (`data/` is
gitignored). Point a config at your local copy of the CSV that
[`original/create_database.R`](original/create_database.R) writes:

```r
config <- load_config("inst/configs/cfin_gom.yaml")   # edit paths.zoop_file first
result <- run_taupatch(config)
```

## Configuration

A config is one YAML file describing one run, so two runs differ by a file rather
than by edited code. There are eight top-level blocks:

```yaml
# 1. Where things live. Every relative path is resolved against project_dir,
#    and project_dir itself against this file's own location.
paths:
  project_dir: '.'
  zoop_file: data/zooplankton_database.csv
  output_dir: output/cfin_gom

# 2. What the station columns are called in YOUR database. These are the
#    defaults, so this block can be omitted entirely if your columns match.
columns:
  lat: lat
  lon: lon
  year: year
  month: month
  day: day

# 3. Which species, and what counts as a patch.
species:
  active: cfin
  catalog:
    cfin:
      threshold: {type: percentile, value: 0.9}   # top 10% of stations
    ctyp:
      threshold: {type: percentile, value: 0.9}

# 4. Which observations the model is fitted on.
dates:
  years: [2003, 2017]
  months: [1, 12]

# 5. Where. Covariates are downloaded for this box, and stations outside it are
#    dropped. Draw it wider than your stations if you use gradients or fronts.
study_area:
  bbox: {xmin: -76.0, xmax: -65.0, ymin: 35.0, ymax: 45.0}

# 6. What the model predicts from.
covariates:
  source: copernicus              # or: local_netcdf, mock
  selected: [SST, SSS, BOTT, MLD, CHL]
  bathymetry: [DEPTH, SLOPE]
  derived: [jday]
  prejoin:
    - type: upscale
      covariate: CHL
      to: SST
  derivoce:
    - type: horizontal_gradient
      vars: [SST]
  transform:
    log1p: [CHL, DEPTH]
  normalize: true

# 7. How it is fitted.
model:
  type: rf                  # rf | brt | glm | gam
  trees: 500
  cv_folds: 10
  tune: false
  seed: 42

# 8. What gets mapped. Omit years/months to reuse the training window.
projection:
  years: [2003, 2017]
  months: [1, 12]
  write_geotiff: true
  write_png: true
  overwrite: true
```

Only `paths`, `species`, `dates`, `study_area` and `covariates` have no usable
defaults; you can leave the rest out entirely.

**Three ways to get one.** Generate it, which validates as it writes:

```r
generate_config("cfin_gom", zoop_file = "data/zooplankton_database.csv",
                selected = c("SST", "SSS", "CHL"), bathymetry = "DEPTH",
                transform = list(log1p = c("CHL", "DEPTH")))
```

Copy the worked example, `inst/configs/cfin_gom.yaml`, which is the same thing
with every field explained inline. Or build it in the app and press **Download
config**.

Either way, check it before running — `load_config()` applies the defaults and
validates everything cheap to check, and an error there costs a second where the
same mistake found mid-run costs however long the download took:

```r
config <- load_config("my_run.yaml")
```

→ [**Configuring a run**](vignettes/configuring.Rmd) is the reference for every
block: species and life stages, thresholds, covariates and derived covariates,
transformations, prejoin steps, combining products of different resolution,
jackknifing which covariates earn their place, model types and ensembles,
comparing two runs, training and projection windows, and how far to trust a map.

## Outputs

Each run writes to `paths.output_dir`:

```
model.rds              fitted tidymodels workflow (or the whole ensemble object)
evals.csv              performance, stating the cutoff each metric belongs to
cv_metrics.csv         the raw per-fold resampling table
var_importance.csv     permutation variable importance
var_importance.png
threshold.yaml         the abundance threshold used, and the probability cutoff with its interval
covariate_jackknife.csv    with covariates.jackknife: each covariate's contribution and its p-value
ensemble_members.csv       with model.ensemble: each algorithm's score, weight, and whether it qualified
member_cv_metrics.csv      with model.ensemble: the per-fold resampling table, per algorithm
diagnostics/roc_curve.png, pr_curve.png, calibration.png, threshold_performance.png
diagnostics/cv_predictions.csv     held-out predictions, for any metric not tabulated
diagnostics/partial_effects.png    what each predictor does to patch probability
diagnostics/coefficients.png       glm only: signed effects with intervals
diagnostics/smooth_terms.csv       gam only: effective degrees of freedom per smooth
diagnostics/gam_smooths.png        gam only: fitted smooths with error bands, drawn by fancyfx
diagnostics/members/<type>/        with model.ensemble: the above, one directory per algorithm
projections/suitability.csv       every cell of every month: species, year, month, lon, lat, probability
                                  plus the interval and novelty columns, with projection.uncertainty
projections/suitability.grd       the same, as one raster with a layer per month (projection.write_grd)
projections/<species>_<year>_<month>.tif      one layer, or one per surface with projection.uncertainty
plots/<species>_<year>_<month>.png
plots/<species>_<year>_<month>_uncertainty.png   the spread and novelty panels, with projection.uncertainty
covariates/monthly_means.csv       study-area mean per covariate, month, and year
covariates/<covariate>_heatmap.png month-by-year heatmap
bathymetry/                        marmap's cached NOAA download, if used
```

## Repository layout

```
R/config.R              load_config(), generate_config()
R/zoop_data.R           load_zoop_data(), label_patch(), available_stages()
R/raw_data.R            format_zoop_data(), zoop_taxa(), split_dates()
R/covariate_catalog.R   copernicus_covariates(), covariate_info()
R/covariates.R          fetch_covariates(), attach_covariates(), covariate_grid()
R/bathymetry.R          bathymetry_covariates(), the static seafloor layers
R/prejoin.R             prejoin_steps(), apply_prejoin_steps()
R/derivoce.R            derivoce_covariates(), add_derivoce_covariates()
R/model.R               fit_patch_model()
R/model_types.R         model_types(), permutation_importance()
R/jackknife.R           jackknife_covariates(), the leave-one-out covariate test
R/ensemble.R            fit_patch_ensemble(), combining several model types
R/power.R               compare_runs(), power_curve()
R/parallel.R            the worker pool both of those run on
R/plot_effects.R        partial_effects(), glm_coefficients(), gam_smooth_terms()
R/uncertainty.R         novelty_surface(), the projection interval
R/evaluation_boot.R     bootstrap_evaluation(), the interval on every metric
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

## Documentation

| | |
|---|---|
| [Getting started](vignettes/taupatch.Rmd) | one complete run on synthetic data — fit, evaluate, project, read the maps — plus the full reference list |
| [Configuring a run](vignettes/configuring.Rmd) | every config block, what each field means, and what happens when you change it |

## Citation

The paper this model comes from:

> Ross CH, Runge JA, Roberts JJ, Brady DC, Tupper B, Record NR (2023).
> Estimating North Atlantic right whale prey based on *Calanus finmarchicus*
> thresholds. *Marine Ecology Progress Series* 703:1–16.
> [doi:10.3354/meps14204](https://doi.org/10.3354/meps14204)

```
@article{ross2023calanus,
  author  = {Ross, C. H. and Runge, J. A. and Roberts, J. J. and Brady, D. C.
             and Tupper, B. and Record, N. R.},
  title   = {Estimating North Atlantic right whale prey based on
             {Calanus finmarchicus} thresholds},
  journal = {Marine Ecology Progress Series},
  year    = {2023},
  volume  = {703},
  pages   = {1--16},
  doi     = {10.3354/meps14204}
}
```

`citation("taupatch")` returns this entry along with one for the software itself.
Cite the paper for the method and the package for the implementation.

## References

taupatch is mostly plumbing between other people's data and other people's
methods, and the obligation to cite travels with those rather than with this
package. **Cite whichever of these your run actually used** — the full list,
grouped by what it covers (the model, the station data, environmental and
derived covariates, transformations, models, evaluation, and the software this
is built on), is at the end of the [getting started
vignette](vignettes/taupatch.Rmd). `covariate_info()` names the source of every
covariate at runtime, and each function's `?help` carries the references relevant
to it.
