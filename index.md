# taupatch

**Contents**

- [Run it without writing code](#run-it-without-writing-code)
- [Installation](#installation)
- [Try it without any data](#try-it-without-any-data)
- [Running on real data](#running-on-real-data)
- [Configuration](#configuration)
  - [A complete config, walked
    through](#a-complete-config-walked-through)
  - [Three ways to get one](#three-ways-to-get-one)
  - [Species and life stages](#species-and-life-stages)
  - [Thresholds](#thresholds)
  - [Covariates](#covariates)
  - [Derived covariates](#derived-covariates)
  - [Transformations](#transformations)
  - [Preparing covariates before the
    join](#preparing-covariates-before-the-join)
  - [Combining products of different
    resolution](#combining-products-of-different-resolution)
  - [Testing which covariates earn their
    place](#testing-which-covariates-earn-their-place)
  - [Model type](#model-type)
  - [Fitting all of them at once](#fitting-all-of-them-at-once)
  - [Comparing two runs, and knowing when you
    cannot](#comparing-two-runs-and-knowing-when-you-cannot)
  - [Training and projection windows](#training-and-projection-windows)
  - [How far to trust a map](#how-far-to-trust-a-map)
  - [Reading the evaluation](#reading-the-evaluation)
- [Outputs](#outputs)
- [Repository layout](#repository-layout)
- [Citation](#citation)
- [References](#references)

Monthly spatial habitat suitability models for **high-abundance
zooplankton patches** (“tau-patches”), where a patch is any station
whose abundance exceeds a species-specific threshold.

Station data is matched to Copernicus Marine environmental covariates
with [`datamatch`](https://github.com/chross22/datamatch). You can add
covariates derived from that grid with
[`derivoce`](https://github.com/chross22/derivoce): gradients, fronts,
lags, and flow diagnostics. Stations are then classified against the
abundance threshold and modeled with a
[tidymodels](https://www.tidymodels.org) workflow (Kuhn & Wickham 2020).
The fitted model is projected to a habitat suitability map for every
month you configure — a presence/absence species distribution model in
the sense of Elith & Leathwick (2009), where “presence” is a patch
rather than an animal.

This is the model from [Ross et al.
(2023)](https://doi.org/10.3354/meps14204), *Estimating North Atlantic
right whale prey based on* Calanus finmarchicus *thresholds*, rebuilt as
an R package. The original `biomod2` pipeline (Thuiller et al. 2009) is
kept unmodified in
[`original/`](https://camilleross.org/taupatch/original/).

Species, life stages, covariates, thresholds, study area, and model
settings all come from a YAML config now, rather than from editing code.
See
[`docs/rebuild_plan.md`](https://camilleross.org/taupatch/docs/rebuild_plan.md)
for what changed and why.

Every work cited below is listed under [References](#references) at the
very bottom, and each function’s own
[`?help`](https://rdrr.io/r/utils/help.html) carries the references
relevant to it. **If you publish from a run, cite the data and methods
that run actually used** — the reference list is grouped so you can pick
out exactly those.

## Run it without writing code

The whole model runs from a GUI. Point it at a station CSV, pick a
species and a threshold, choose covariates, press Run — no config file
and no R beyond the one line that starts it.

``` r

install.packages("remotes")
remotes::install_github("chross22/taupatch")
taupatch::run_taupatch_app()
```

That opens on synthetic data, so it works before you have Copernicus
credentials or a station database. To model your own, put its path in
the sidebar: the file is read where it already is and never copied, a
raw NEFSC export is reshaped for you, and the columns are checked before
a run starts rather than partway through one.

Everything is a control rather than a config field — species, life
stages, threshold, windows, study area, covariates, derived covariates,
transforms, model type. Press **Download config** and the run you
clicked your way to becomes a YAML file you can re-run or hand to
someone else. The rest of this README is that same pipeline driven from
a config, for when a run needs scripting or repeating.

Tabs, in the order the questions come up:

- **Config** — the exact YAML the run would use, updating as you click,
  so nothing done in the GUI is unreachable from a script
- **Zooplankton data** — the stations before any model touches them:
  where they are, how abundance moves over the record, its distribution
  with the patch threshold drawn on. A study area wider than the survey,
  or an abundance field that is mostly zeros, shows here and nowhere
  else
- **Covariate trends** — each covariate’s study-area mean by month and
  year, and a map of the field itself for any month, so a covariate that
  failed to download or is masked over the wrong water is visible
- **Results** — cross-validated metrics, variable importance, the
  threshold used
- **Diagnostics** — ROC, precision-recall, calibration, and partial
  effects for every predictor. A GAM also gets its fitted smooths and
  mgcv’s full summary
- **Maps** — monthly suitability on a basemap, with the probabilities
  downloadable as GeoTIFFs, a CSV carrying coordinates and dates, or one
  multi-layer raster
- **Log** — stage by stage, including how many grid cells each month
  lost and to which covariate, which is what explains a patchy map
- **Covariate dictionary** — every covariate’s units, resolution, and
  definition

## Installation

``` r

# install.packages("remotes")
remotes::install_github("chross22/taupatch")
```

**To get the vignette, ask for it.** `install_github()` does not build
vignettes by default — it is faster not to, and most installs do not
want them — so
[`vignette("taupatch")`](https://camilleross.org/taupatch/articles/taupatch.md)
finds nothing after a plain install. That is the install being
economical, not the vignette being missing:

``` r

remotes::install_github("chross22/taupatch", build_vignettes = TRUE)
vignette("taupatch")
```

Building it needs `knitr` and `rmarkdown`, and it runs the whole
pipeline on the mock data as it renders, so expect it to take a minute
rather than a moment. If you would rather not rebuild, [read it on
GitHub](https://camilleross.org/taupatch/vignettes/taupatch.Rmd) instead
— the same document, without the rendered figures.

Environmental data needs the [Copernicus Marine
Toolbox](https://help.marine.copernicus.eu/en/collections/4060068-copernicus-marine-toolbox)
(EU Copernicus Marine Service 2025) installed and configured with your
Copernicus credentials, plus:

``` r

remotes::install_github("chross22/datamatch")
```

`datamatch` no longer depends on `BigelowLab/copernicus` — it calls the
Copernicus Marine Toolbox directly — so that package no longer needs
installing.

Derived covariates (`covariates.derivoce`) additionally need:

``` r

remotes::install_github("chross22/derivoce")
```

The Shiny app additionally needs `shiny`, `leaflet`, and `shinyFiles`.

## Try it without any data

The app above opens on synthetic data, and so does the **[Getting
started
vignette](https://camilleross.org/taupatch/vignettes/taupatch.Rmd)**,
which walks one complete run — fit, evaluate, project, read the maps —
and is the place to start if you would rather follow a worked example
than read reference material:

``` r

vignette("taupatch")
```

The same run headless, with no Copernicus credentials and no network
access:

``` r

config <- load_config(system.file("configs/mock_test.yaml", package = "taupatch"))
config$paths$zoop_file <- file.path(tempdir(), "mock.csv")
config$paths$output_dir <- file.path(tempdir(), "out")
generate_mock_zoop_data(config)

result <- run_taupatch(config)
result$model$evaluation   # performance, with the cutoff each metric belongs to
result$model$importance   # permutation variable importance
result$projections        # one GeoTIFF + PNG per projected month
```

The mock data plants a latitudinal gradient and a seasonal cycle into
both abundance and the covariates. A working pipeline therefore scores
well above chance. A smoke test that passed on noise would not be
testing anything.

## Running on real data

If you have the raw ECOMON export rather than a formatted database,
build one first. That export is NOAA’s Ecosystem Monitoring plankton
dataset (NOAA NEFSC, NCEI Accession 0187513), which is not distributed
with this package and carries its own citation:

``` r

formatted <- format_zoop_data("raw_ecomon.csv", write_to = "data/zooplankton.csv")
zoop_taxa("raw_ecomon.csv")     # every taxon the file carries
```

It splits `DATE` into year, month and day, renames
`LATITUDE`/`LONGITUDE`, and strips the units off each taxon column, so
`CALANUS_FINMARCHICUS_10M2` becomes `CALANUS_FINMARCHICUS`. Some
datasets resolve life stages, marked by a `C` and a Roman numeral. Those
keep the stage (`CALANUS_FINMARCHICUS_CV`), which is the form
`column_prefix` and `stages` match. A taxon without one is that taxon’s
total. Everything else in the file is carried through untouched,
including the in-situ measurements it already holds, which are kept but
not used as covariates.

[`species_catalog_from()`](https://camilleross.org/taupatch/reference/species_catalog_from.md)
writes the matching `species.catalog`, giving each taxon whichever form
its columns support:

``` r

generate_config("my_run", zoop_file = "data/zooplankton.csv",
                species = species_catalog_from("raw_ecomon.csv",
                                               aliases = c(cfin = "CALANUS_FINMARCHICUS")))
```

The zooplankton database is not included and should not be committed
(`data/` is gitignored). Point a config at your local copy of the CSV
that
[`original/create_database.R`](https://camilleross.org/taupatch/original/create_database.R)
writes:

``` r

config <- load_config("inst/configs/cfin_gom.yaml")   # edit paths.zoop_file first
result <- run_taupatch(config)
```

`inst/configs/cfin_gom.yaml` is a documented example — *Calanus
finmarchicus* from ECOMON stations with monthly Copernicus physical
covariates. Generate new configs programmatically rather than
hand-editing YAML:

``` r

generate_config("ctyp_shelf", active_species = "ctyp", years = c(2005, 2015),
                selected = c("SST", "SSS", "CHL"),
                transform = list(fourth_root = "CHL"))
```

Covariates are named the way the rest of the package names them. The
file leads with comments saying where those names come from. It is also
loaded back and validated before the path is returned, so a mistyped
covariate is an error at that call rather than five minutes into a run.

## Configuration

A config is one YAML file describing one run. Species, thresholds,
dates, study area, covariates, and model settings all live in it. Two
runs differ by a file rather than by edited code.

### A complete config, walked through

There are eight top-level blocks. This is all of them, with every field
a normal run sets:

``` yaml
# 1. Where things live. Every relative path is resolved against project_dir,
#    and project_dir itself against this file's own location - so a config with
#    '.' works no matter what your R working directory is.
paths:
  project_dir: '.'
  zoop_file: data/zooplankton_database.csv   # the station database
  output_dir: output/cfin_gom                # created if absent

# 2. What the station columns are called in YOUR database. These are the
#    defaults, so this block can be omitted entirely if your columns match.
columns:
  lat: lat
  lon: lon
  year: year
  month: month
  day: day

# 3. Which species, and what counts as a patch. `active` picks one from the
#    catalog; the others stay defined so switching species is a one-word edit.
species:
  active: cfin
  catalog:
    cfin:
      column_prefix: cfin        # defaults to the key, so this is optional
      threshold:
        type: percentile         # or: absolute
        value: 0.9               # top 10% of stations are patches
    ctyp:
      column_prefix: ctyp
      threshold: {type: percentile, value: 0.9}

# 4. Which observations the model is fitted on.
dates:
  years: [2003, 2017]
  months: [1, 12]

# 5. Where. Covariates are downloaded for this box, and stations outside it are
#    dropped. Draw it wider than your stations if you use gradients or fronts -
#    those are undefined on the edge.
study_area:
  bbox: {xmin: -76.0, xmax: -65.0, ymin: 35.0, ymax: 45.0}

# 6. What the model predicts from. See the sections below for each sub-block.
covariates:
  source: copernicus              # or: local_netcdf, mock
  selected: [SST, SSS, BOTT, MLD, CHL]   # time-varying, from Copernicus
  bathymetry: [DEPTH, SLOPE]             # static, from NOAA ETOPO
  derived: [jday]                        # day of year; the seasonality term
  prejoin:                               # per-covariate prep, before the join
    - type: upscale
      covariate: CHL
      to: SST
  derivoce:                              # computed from the grid, optional
    - type: horizontal_gradient
      vars: [SST]
  transform:                             # optional; one transform per covariate
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

Only `paths`, `species`, `dates`, `study_area`, and `covariates` have no
usable defaults. You can leave the rest out entirely.

### Three ways to get one

**Generate it**, which is the shortest path and validates as it writes:

``` r

generate_config("cfin_gom", zoop_file = "data/zooplankton_database.csv",
                selected = c("SST", "SSS", "CHL"), bathymetry = "DEPTH",
                transform = list(log1p = c("CHL", "DEPTH")))
```

**Copy the worked example**, `inst/configs/cfin_gom.yaml`, which is the
same thing with every field explained inline:

``` r

file.copy(system.file("configs", "cfin_gom.yaml", package = "taupatch"),
          "my_run.yaml")
```

**Build it in the app** and download the config it produces, which is
the way to keep a run you arrived at by clicking. See [Run it without
writing code](#run-it-without-writing-code).

Either way, check it before running.
[`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)
applies the defaults and validates everything that is cheap to check.
That the species resolves, the thresholds are well-formed, the covariate
names exist, the transforms name covariates the run actually fetches,
and the declared columns are present in your CSV:

``` r

config <- load_config("my_run.yaml")
config$covariates$selected
```

An error here costs a second. The same mistake found during a run costs
however long the Copernicus download took to get there.

### Species and life stages

A catalog entry answers one question: **which column or columns hold
this species’ abundance?** There are two ways to answer it, and which
one an entry uses is not a style choice — it depends on how the database
reports the taxon.

| entry form | use it when | what a run can then do |
|----|----|----|
| `column_prefix: cfin` | the database resolves life stages, as `cfin_CV`, `cfin_CVI`, … | select particular `stages`, or leave `stages` out to sum every one |
| `abundance_column: CENTROPAGES_TYPICUS` | the database reports one total and no stages | nothing to select — the column *is* the abundance |

`column_prefix` matches `<prefix>_<something>`, which is why it needs
stage columns to match against; `abundance_column` names a single column
outright. Setting both is an error, and so is setting `stages` alongside
`abundance_column`, because there are no stage columns for it to narrow
to.

**You do not have to work this out per taxon.**
[`species_catalog_from()`](https://camilleross.org/taupatch/reference/species_catalog_from.md)
reads the database and writes the block, choosing the right form for
each:

``` r

header <- c("CALANUS_FINMARCHICUS_CV_10M2", "CALANUS_FINMARCHICUS_CVI_10M2",
            "CENTROPAGES_TYPICUS_10M2")

species_catalog_from(header, aliases = c(cfin = "CALANUS_FINMARCHICUS"))
#> $cfin
#> $cfin$column_prefix          # stages resolved, so a prefix
#> [1] "CALANUS_FINMARCHICUS"
#> $cfin$threshold
#> $cfin$threshold$type
#> [1] "percentile"
#> $cfin$threshold$value
#> [1] 0.9
#>
#> $ctyp
#> $ctyp$abundance_column       # a total only, so a column
#> [1] "CENTROPAGES_TYPICUS"
```

`aliases` is what lets a config say `cfin` instead of
`CALANUS_FINMARCHICUS`; without it the key is a shorthand derived from
the taxon name. The result goes straight into
[`generate_config()`](#three-ways-to-get-one) as `species`.

Three functions, three different questions — it is worth knowing which
you want:

|  | question |
|----|----|
| `zoop_taxa(raw_export)` | which taxa does this **raw** export carry, with units still on the names? |
| `available_species(database)` | which taxa could I model from this **formatted** database? |
| `species_catalog_from(header)` | write me the catalog block for them |

Once you have a catalog, `column_prefix` defaults to the species key, so
only an aliased name needs it — `pcal` is the one case in the ECOMON
database, since its columns are `pseudo_*`:

``` yaml
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

``` yaml
    cfin:
      stages: [CV, adult]
```

Which stages exist differs by species, so read them off the data rather
than assuming:

``` r

available_stages("data/zooplankton_database.csv", "cfin")
#> "CI" "CII" "CIII" "CIV" "CV" "CVI" "adult"
```

Only individually resolved stages are selectable. The database also
holds columns spanning several stages (`ctyp_CV_CVI`, `pseudo_CI_IV`,
…), which overlap the single stages and would double-count if mixed with
them. Two consequences worth knowing:

- **`cfin_CV_VI` is offered as `adult`.** ECOMON does not resolve CV
  from CVI for *C. finmarchicus* and reports the combined count, which
  is the adult number. Selecting `adult` together with `CV` or `CVI` is
  rejected as double-counting.
- **Leaving `stages` empty sums every column**, combination columns
  included, reproducing `<prefix>_total`. This is what keeps a default
  ECOMON run working.

### Thresholds

A patch is a station at or above the threshold, given either as a
percentile of the observed distribution or as an absolute abundance:

``` yaml
threshold: {type: percentile, value: 0.9}   # top 10% of stations
threshold: {type: absolute, value: 2063.3}  # individuals/m2
```

The type is explicit because the original inferred it from whether the
value was below 1, which silently misreads any real threshold under 1.
Each run writes the computed threshold to `threshold.yaml`, so a
percentile run can be reproduced as an absolute one.

### Covariates

Covariates are named the way people refer to them and resolve to a
Copernicus product, dataset, and variable. Those sharing a dataset are
fetched in one request:

``` yaml
covariates:
  selected: [SST, SSS, BOTT, MLD, CHL]
  derived: [jday]
  transform:
    log1p: [CHL]
```

``` r

covariate_info()[, c("name", "label", "units")]
```

| Name                   | Long name                              | Units       |
|------------------------|----------------------------------------|-------------|
| SST                    | Sea surface temperature                | degrees C   |
| SSS                    | Sea surface salinity                   | PSU         |
| BOTT                   | Bottom temperature                     | degrees C   |
| UO / VO                | Eastward / northward current velocity  | m/s         |
| SSH                    | Sea surface height                     | m           |
| MLD                    | Mixed layer depth                      | m           |
| CHL                    | Chlorophyll-a concentration            | mg/m3       |
| NO3                    | Nitrate concentration                  | mmol/m3     |
| O2                     | Dissolved oxygen                       | mmol/m3     |
| DEPTH / SLOPE / ASPECT | Seafloor depth, slope, aspect (static) | m, degrees  |
| jday                   | Day of year (derived)                  | day (1–366) |

These come from three Copernicus Marine products, each of which should
be cited when a run uses it: the **Global Ocean Physics Reanalysis**
(GLORYS12V1) for `SST`, `SSS`, `BOTT`, `UO`, `VO`, `SSH`, `MLD`; the
**Global Ocean Colour** (Copernicus-GlobColour) satellite product for
`CHL`, `PP`; and the **Global Ocean Biogeochemistry Hindcast** for
`NO3`, `O2`, `CHL_MODEL`.
[`covariate_info()`](https://camilleross.org/taupatch/reference/covariate_info.md)
names the dataset behind each covariate, and the
[References](#references) give the product DOIs.

`jday` is what lets one pooled model produce month-specific maps instead
of requiring twelve separate models.

**Seafloor covariates are static** — they don’t vary by month, so
they’re downloaded once from NOAA ETOPO 2022 (NOAA NCEI 2022) via
[`marmap::getNOAA.bathy()`](https://rdrr.io/pkg/marmap/man/getNOAA.bathy.html)
(Pante & Simon-Bouhet 2013) and attached to every time step. They go
under their own config key, since they don’t come from Copernicus:

``` yaml
covariates:
  selected: [SST, SSS, CHL]     # Copernicus, time-varying
  bathymetry: [DEPTH, SLOPE]    # NOAA ETOPO, static
  transform:
    log1p: [CHL, DEPTH]
```

These replace the SRTM30 depth/slope layers the original used.

### Derived covariates

Gradients, fronts, lags, integrals, and flow diagnostics are computed
rather than downloaded, by
[`derivoce`](https://github.com/chross22/derivoce). They go under
`covariates.derivoce` as a list of steps, each naming a derivoce
function and the arguments for it:

``` yaml
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
      "n": 1                   # CHL_lag1 - see the note on quoting below
    - type: integrate_covariate
      vars: [CHL]
      window: year             # CHL_int, the original pipeline's int_chl
    - type: current_speed      # speed, the original pipeline's uv
    - type: horizontal_gradient
      vars: [speed]            # speed_grad, its uv_grad
    - distance_to_shore        # shore_dist, its dist
```

**Why `"n"` is quoted.** YAML 1.1 — which is what
[`yaml::read_yaml()`](https://yaml.r-lib.org/reference/read_yaml.html)
parses — reads a bare `n` as the boolean `false`, along with `y`, `yes`,
`no`, `on` and `off`. So `n: 2` names the key `FALSE` rather than `n`,
and a plain parser hands back a step with no `n` at all, which silently
falls back to a one-month lag.
[`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)
recovers the spelling, so an unquoted `n: 2` does work here. The quotes
are for everything else that might open the file.

Steps run in order and see the columns earlier ones produced. That is
why `current_speed` followed by a gradient of `speed` works.
`distance_to_front`, `distance_to_contour`, `distance_to_isobath`,
`ftle`, and `fsle` are available too.
[`derivoce_covariates()`](https://camilleross.org/taupatch/reference/derivoce_covariates.md)
lists every step type with its units and the column names it produces.

Each of these implements a published method, and the citation belongs to
that method rather than to this package: front detection follows Belkin
& O’Reilly (2009), the Lyapunov exponents follow Haller (2015) and
d’Ovidio et al. (2004), and `distance_to_shore` measures against
[Natural Earth](https://www.naturalearthdata.com/) coastlines.
derivoce’s own [reference
list](https://github.com/chross22/derivoce#references) is the complete
one, and [`?derivoce::ftle`](https://rdrr.io/pkg/derivoce/man/ftle.html)
and friends carry the reference for each function.

These are computed **on the covariate grid, before stations are matched
to it**. A gradient or a front is a property of the field, and scattered
station points cannot recover one. After that they behave like any other
covariate column. They are matched to stations, carried onto the
projection grid, and picked up as predictors automatically.
`covariates.transform` can name them.

Three things cost data, and a run says so when they happen:

- Lags, integrals, and temporal gradients are undefined in the first
  month of the record. Stations there are dropped, and that month’s
  projection is skipped.
- Neighbourhood steps are undefined on the edge of the study area. That
  means gradients, fronts, and Lyapunov exponents. The border is lost
  from both the training stations and the maps, so draw the bounding box
  wider than the stations.
- A neighbourhood step reading an upsampled variable warns, for the
  reason below.

### Transformations

Each covariate takes at most one transform, named under
`covariates.transform`:

``` yaml
covariates:
  transform:
    log1p: [CHL, DEPTH]     # log(1 + |x|) - the default, defined at zero
    fourth_root: [NO3]
    yeojohnson: [SST_tgrad]
  normalize: true           # centre and scale; on unless turned off
```

| Name | What it is |
|----|----|
| `log1p` | `log(1 + \|x\|)`. Defined at zero, which the plain logs are not |
| `log` / `log10` | Natural and base-10 log of the magnitude |
| `sqrt` / `fourth_root` | Milder compression, defined at zero; fourth root is the plankton standard, after Field et al. (1982) |
| `boxcox` | Estimates the best power per covariate (Box & Cox 1964); needs strictly positive input |
| `yeojohnson` | Box-Cox extended to zero and negative values (Yeo & Johnson 2000) |

Two rules the package checks against the data rather than trusting:

- **`log` and `log10` are undefined at zero.** Zeros are ordinary in
  chlorophyll and in any derived integral that starts there. Asking for
  one on a column containing zeros is an error that points you at
  `log1p`.
- **The log and root family takes `abs(x)` first.** That is right for a
  magnitude stored with a sign convention, like negative depth. It is
  wrong for a genuinely signed covariate, where it maps `-2` and `2`
  onto the same predictor. Derived covariates make this common, since
  temporal gradients, vertical gradients, and current components are all
  signed. Those columns warn. Use `yeojohnson` for them instead.

[`covariate_transforms()`](https://camilleross.org/taupatch/reference/covariate_transforms.md)
lists all of them. `covariates.log_transform` still works and still
means `log1p`.

### Preparing covariates before the join

The join below is all-or-nothing: `covariates.grid` decides for every
covariate at once, and it reconciles grids by replication.
`covariates.prejoin` is the per-covariate alternative, applied *before*
the join, so the join then sees grids that already agree and leaves them
alone:

``` yaml
covariates:
  selected: [SST, SSS, CHL, CHL_MODEL]
  prejoin:
    - type: fill_gaps
      covariate: CHL
      from: CHL_MODEL     # consumed, not kept — keep_source: true to retain it
      rescale: false
    - type: upscale
      covariate: CHL
      to: SST             # another covariate's grid, or a number of degrees
      method: median
```

| Step | What it does |
|----|----|
| `upscale` | Aggregates onto a coarser grid: `mean`, `median`, `min`, `max` |
| `downscale` | Interpolates onto a finer grid: `nearest`, `bilinear`, `idw` |
| `fill_gaps` | Substitutes another covariate wherever the first is missing |

Steps run in order and see what earlier ones produced, so the pair above
fills chlorophyll’s cloud gaps and *then* regrids the filled field.

The right treatment differs by covariate, which is why this is
per-covariate. Averaging chlorophyll up to the physics grid summarises
values that were really measured. Interpolating physics down to 4 km
invents structure. One global setting cannot say both.

The computation is all `datamatch`, and so are the trade-offs. What each
method does, when downscaling invents structure rather than revealing
it, and what the `<covariate>_source` column records after a fill are
documented in [datamatch’s resampling
section](https://github.com/chross22/datamatch#resampling) rather than
repeated here.

One behaviour is taupatch’s own. **The filling covariate is dropped from
the join by default.** It was fetched as a means rather than an end, and
keeping it would hand the model two near-identical predictors. Set
`keep_source: true` to retain it.

[`prejoin_steps()`](https://camilleross.org/taupatch/reference/prejoin_steps.md)
lists the step types.

### Combining products of different resolution

Copernicus products do not share a grid — physics is 0.083 degrees,
biogeochemistry 0.25 — so selecting `SST` and `CHL` together means two
grids that have to be reconciled onto one. `covariates.grid` decides
which:

``` yaml
covariates:
  selected: [SST, SSS, CHL]
  grid: finest      # or: coarsest
```

- **`finest`** (the default) keeps the finest grid and repeats each
  coarse cell’s value across the fine cells inside it. Fine-scale
  structure survives in the fine variables. That matters because fronts
  and gradients are computed from them.
- **`coarsest`** joins onto the coarsest grid, so no value is ever
  replicated.

The cost of `finest` is worth stating plainly. **A coarse variable
rendered on a fine grid is blocky, not detailed.** Its values are
constant within each original cell and step at the boundaries. So a
spatial gradient computed from an upsampled variable is an artifact:
zero inside each block, spiking at edges that belong to the source grid
rather than the ocean. Compute gradients from variables at their native
resolution.

A run reports which covariates were upsampled, and records them on the
result as an `upsampled` attribute.

### Testing which covariates earn their place

`covariates.jackknife` refits the model without each covariate in turn
and asks how much worse it ranks stations. Off by default, because it is
a full cross-validation per covariate — twice over, since it also fits
each covariate alone — which is why it parallelizes:

``` yaml
covariates:
  jackknife: true             # or the block below, to change the defaults
```

``` yaml
covariates:
  jackknife:
    metric: roc_auc           # or: pr_auc
    criterion: fold           # or: parametric  (glm and gam only)
    alpha: 0.05
    adjust: holm              # or: BH, bonferroni, none
    drop: false               # DEFAULT: report, never remove on its own
    keep: [DEPTH, jday]       # never dropped, whatever the test says
    min_predictors: 2
    workers: true             # true = cores - 1; a count; false = sequential
```

It writes `covariate_jackknife.csv`, one row per covariate:

| variable | score_full | score_without | score_only | contribution | p_value | p_adjusted | significant |
|----|----|----|----|----|----|----|----|
| SST | 0.857 | 0.791 | 0.812 | 0.066 | 0.004 | 0.020 | TRUE |
| DEPTH | 0.857 | 0.828 | 0.774 | 0.029 | 0.031 | 0.124 | FALSE |
| jday | 0.857 | 0.855 | 0.611 | 0.002 | 0.402 | 0.402 | FALSE |

The two halves answer different questions and the pair is what makes the
table readable. **`score_without`** is low when the covariate carries
something no other covariate has — its *unique* contribution.
**`score_only`** is high when it carries a lot on its own, whether or
not anything else carries it too. A covariate can score high on one and
nothing on the other, and that combination is the informative one:
`DEPTH` above is worth as much alone as `SST` is, and almost nothing on
top of what the rest already say.

**The significance test.** Every refit uses the same cross-validation
folds as the main model, so the comparison is paired fold by fold and
none of the difference is the split moving underneath it. The reported
`p_value` is a one-sided test of whether leaving the covariate out makes
the model worse, computed from the per-fold differences with the
variance correction of Nadeau & Bengio (2003).

The correction is load-bearing. A plain paired t-test treats the folds
as independent, and they are not — any two training sets share most of
their rows — so its variance estimate is badly optimistic and it calls
far too much significant (Dietterich 1998). There is no unbiased
estimator of the variance of k-fold cross-validation (Bengio &
Grandvalet 2004); this inflates the naive variance by `1/k + 1/(k-1)`
instead, which roughly halves the *t* statistic. `p_adjusted` then
accounts for having asked the question once per covariate.

For a GLM and a GAM there is a classical test of the same hypothesis,
and it is reported *beside* the fold test rather than instead of it: a
drop-in-deviance likelihood ratio test for `glm`, and `mgcv`’s
approximate term p-value for `gam` (approximate because it conditions on
smoothing parameters estimated from the same data, so it runs
anti-conservative — Wood 2017 §6.12). A forest and a boosted tree have
no likelihood, so those columns are `NA` there. That is why
`criterion: fold` is the default: it means the same thing for all four
types.

**Dropping is opt-in, and that is deliberate.** With `drop: false` the
run reports the table, says what dropping *would* have removed, and fits
on everything. A covariate that fails this test is one the *other
covariates already account for* on these stations, which is a statement
about collinearity in this sample at least as much as about ecology.
Bottom depth and sea surface temperature carry much of the same
information on a shelf; the test will happily call either one redundant
depending on which the model reached for first. Removing it silently
would make the map look better while deleting the variable a reader
would have asked about. `keep` is the escape hatch for exactly that: a
covariate that is in the model because the study is about it stays in
the model.

When `drop: true`, the rejected covariates are written into
`covariates.exclude`, which is the mechanism that already existed for
keeping a fetched covariate out of the model. So a dropped covariate is
still downloaded and still available to anything that needs it as an
ingredient — a gradient’s velocity components, say — it just stops being
a predictor. The run’s returned `config` shows exactly what came out.

Called directly it needs no config block at all, which is the way to use
it interactively:

``` r

result <- run_taupatch(config, project = FALSE)
jk <- jackknife_covariates(result$data, config)

jk[c("variable", "score_without", "score_only", "contribution", "p_adjusted",
     "significant")]
#>   variable score_without score_only contribution p_adjusted significant
#> 1      SST         0.791      0.812        0.066      0.020        TRUE
#> 2    DEPTH         0.828      0.774        0.029      0.124       FALSE
#> 3     jday         0.855      0.611        0.002      0.402       FALSE

jackknife_dropped(jk)          # what drop would remove, had it been on
#> [1] "DEPTH" "jday"
```

Or from the config, as part of a run. `result$jackknife` is the same
table, and `result$config` shows what the run actually fitted on:

``` r

config$covariates$jackknife <- list(drop = TRUE, keep = "jday", workers = 4)
result <- run_taupatch(config)
#> Jackknifing covariates...
#>   jackknifing 3 covariates: 7 cross-validations across 4 workers
#>   no detectable contribution at alpha = 0.05 (holm-adjusted): DEPTH, jday
#>   covariates.jackknife.drop is on: removing DEPTH

result$config$covariates$exclude
#> [1] "DEPTH"
```

`jday` failed the test and stayed, because `keep` named it. With `drop`
left at its default the last two lines read
`covariates.jackknife.drop is off, so nothing is removed. Setting it would drop: DEPTH, jday`
— and the run fits on everything.

Parallelism forks, which Windows does not have, so it runs sequentially
there and says so. It is one model fit per covariate per fold either way
— minutes, not hours — it just does not get faster with more cores.

### Model type

Four models, chosen with one word:

``` yaml
model:
  type: gam       # rf | brt | glm | gam
  cv_folds: 10
  tune: false
```

| `type` | Model | Engine | Method |
|----|----|----|----|
| `rf` | Random forest | `ranger` (Wright & Ziegler 2017) | Breiman (2001) |
| `brt` | Boosted regression trees | `xgboost` (Chen & Guestrin 2016) | Friedman (2001); Elith et al. (2008) |
| `glm` | Logistic regression | [`stats::glm`](https://rdrr.io/r/stats/glm.html) | McCullagh & Nelder (1989) |
| `gam` | Generalized additive model | `mgcv` (Wood 2011, 2017) | Hastie & Tibshirani (1986) |

They are worth running against each other rather than picking one. If
the GLM and the forest rank the same stations, the relationships are
close to monotonic and the flexible model is not buying much. If they
disagree sharply, either the response is genuinely non-linear or the
forest is fitting noise. The GAM sits in between, and it is the one that
can tell you which. Each of its terms is a curve you can plot, which a
forest cannot give you.

`trees` applies to `rf` and `brt`. `brt` also takes `learn_rate` and
`tree_depth`, and `gam` takes `select_features`, which adds the extra
shrinkage penalty of Marra & Wood (2011) so a term that earns nothing is
removed rather than left wiggling — the `bs: ts` basis is the per-smooth
version of the same idea. `model.method` picks how the smoothing
parameters are estimated; `REML` (Wood 2011) resists the undersmoothing
that GCV is prone to. `model.tune` searches the hyperparameters a type
actually has. A GLM has none, so asking to tune one is an error rather
than a silent no-op.
[`model_types()`](https://camilleross.org/taupatch/reference/model_types.md)
describes each.

**Diagnostics follow the model.** Every type gets partial effect curves
— partial dependence in the sense of Friedman (2001). These show what
each predictor *does* to patch probability, with the others held at the
values they actually take. Importance says a predictor matters. This
says which way, and where it bends. It is computed by prediction rather
than read off the fitted object, so the curves mean the same thing for
all four types and can be laid against each other.

On top of that, each model contributes what only it can:

| `type` | Extra diagnostic |
|----|----|
| `glm` | Signed coefficients with 95% intervals, on a common scale |
| `gam` | Effective degrees of freedom per smooth. An `edf` of 1 means the smooth collapsed to a line |
| `rf` / `brt` | None. The partial effect curve *is* their answer |

With [`fancyfx`](https://github.com/chross22/fancyfx) installed, a GAM
also gets its **fitted smooths** drawn — each term with its standard
error band and a rug showing where the data actually is. Those carry
uncertainty, which a partial dependence curve cannot:

``` r

remotes::install_github("chross22/fancyfx")
```

Their x axes read in standard deviations, because the smooths belong to
the model and the model was fitted on the recipe’s output. Set
`covariates.normalize: false` to read them in the covariate’s own units.
That costs a tree model nothing and a GAM little.

These land in `diagnostics/` alongside the ROC and calibration plots,
and in the app’s Diagnostics tab.
[`model_engine_fit()`](https://camilleross.org/taupatch/reference/model_engine_fit.md)
returns the underlying `ranger`, `xgb.Booster`, `glm`, or `mgcv` object
for anything else that wants to plot a model directly.

**Variable importance is computed the same way for all four.** It is the
drop in ROC AUC when a predictor is shuffled, averaged over several
shuffles — the permutation importance of Breiman (2001), in the
model-agnostic form of Fisher et al. (2019). Engine-reported importances
are not comparable: ranger’s permutation drop and xgboost’s split gain
are different quantities on different scales, and a GLM and GAM have
none at all. One definition is what makes comparing the four meaningful.
It is measured on the training data, so it flatters a model that
overfits in absolute terms, but the ranking holds.

Only `ranger` is needed for the default. `brt` needs `xgboost` and `gam`
needs `mgcv`. Both are checked before fitting rather than at load.

### Fitting all of them at once

Rather than picking one algorithm and hoping, fit several and combine
them. This is `BIOMOD_EnsembleModeling()` from the pipeline this package
replaces:

``` yaml
model:
  type: ensemble            # all four, with the defaults below
```

``` yaml
model:
  type: ensemble
  ensemble:
    types: [rf, brt, glm, gam]
    rule: weighted_mean     # mean | weighted_mean | median | committee
    weight_by: tss          # tss | roc_auc | pr_auc | equal
    min_score: 0.4          # members below this are excluded from the average
    workers: true
    settings:               # per-member overrides of the model block
      gam:
        method: REML
      brt:
        learn_rate: 0.01
```

Everything after the fit works the same either way, so a config that
turns this on gets ensemble projections without changing anything else:

``` r

config$model$type <- "ensemble"
result <- run_taupatch(config)
#> Fitting model...
#>   fitting 4 ensemble members (rf, brt, glm, gam) across 4 workers
#>   ROC AUC: 0.8916
#> Projecting monthly suitability...
#>   combining 4 algorithms by weighted_mean; the other rules and each
#>   member's own surface go beside it

result$model
#> <taupatch ensemble>
#>   rule:  weighted_mean
#>   members (4 of 4 qualifying):
#>  type     score metric qualifies weight
#>   brt 0.6120990    tss      TRUE   0.31
#>    rf 0.6043118    tss      TRUE   0.30
#>   gam 0.5412287    tss      TRUE   0.27
#>   glm 0.2381044    tss      TRUE   0.12
#>
#>   ensemble ROC AUC (out of fold): 0.8916
#>   classification threshold: 0.08881
```

[`fit_patch_ensemble()`](https://camilleross.org/taupatch/reference/fit_patch_ensemble.md)
does the same thing without the pipeline around it, and the result is a
drop-in for a
[`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)
one:

``` r

ensemble <- fit_patch_ensemble(dat, config)
ensemble$summary                         # scores, weights, who qualified
ensemble$evaluation                      # the ensemble's own, out of fold
ensemble$members$gam                     # each member, entire
project_patch_model(ensemble, env_dat, config)
```

**Four ways to combine.** All of them are computed and written on every
run; `rule` picks which one becomes the `suitability` layer, and the
others go beside it — the disagreement between rules is itself worth
looking at, and recomputing them means refitting.

| `rule` | What it does |
|----|----|
| `mean` | Plain average of the probabilities |
| `weighted_mean` | Average in proportion to how well each member scored |
| `median` | Robust average. The one to reach for when a single member is capable of going badly wrong somewhere on the grid — a boosted tree extrapolating, usually. A mean lets that member drag a cell; a median does not |
| `committee` | Each member binarises at *its own* TSS-optimal cutoff, and the cell gets the fraction of members calling it a patch. Reads directly as agreement — 0.75 means three of four algorithms say patch — but throws away how confident each was |

**The ensemble gets its own honest evaluation.** Every member is fitted
on the same folds from the same seed, so their held-out predictions line
up row for row. The ensemble’s out-of-fold predictions are built by
combining members on the rows none of them saw, and the reported
`evals.csv`, the TSS-optimal cutoff and its bootstrap interval all come
from those — the same functions, on the same footing, as a single
model’s. This matters because the obvious alternative is wrong:
averaging the members’ *scores* would report the ensemble as the average
of its parts, and that is not what an ensemble does. Combining members
that make different mistakes beats all of them; combining members that
make the same mistakes does not. Only a cross-validated ensemble
prediction tells those apart.

`ensemble_members.csv` is the first thing to read afterwards:

| type | label                      | score | metric | cutoff | qualifies | weight |
|------|----------------------------|-------|--------|--------|-----------|--------|
| brt  | Boosted regression trees   | 0.612 | tss    | 0.089  | TRUE      | 0.31   |
| rf   | Random forest              | 0.604 | tss    | 0.051  | TRUE      | 0.30   |
| gam  | Generalized additive model | 0.541 | tss    | 0.112  | TRUE      | 0.27   |
| glm  | Logistic regression        | 0.238 | tss    | 0.104  | TRUE      | 0.12   |

A table showing one member near 1.0 and the rest near zero is a single
model with extra steps, and only this file says so. `min_score` is
biomod2’s `metric.select.thresh` under a plainer name, and 0.4 on TSS is
a low bar deliberately — it is there to catch a member that failed to
fit anything, not to tune the ensemble by selecting its best members on
their own evaluation scores, which would be selection on the numbers
used to report it. A member whose package is missing, or that will not
fit, is dropped with a warning rather than failing the run; two is the
floor.

Variable importance is weighted across members, with the per-member
columns kept beside it. A predictor the forest leans on and the GLM
ignores is a fact about the shape of the relationship, and the average
is the one number that hides it. Coefficients and smooths go to
`diagnostics/members/<type>/`, since an ensemble has none of its own and
averaging them would describe a model nobody fitted.

**Two different things are called an ensemble here**, and they are
independent:

|  | Combines over | Its spread means |
|----|----|----|
| `model.ensemble` | **algorithms** | A forest and a logistic regression looking at the same shelf and drawing different maps → `algorithm_sd` |
| `projection.uncertainty` | **resamples of the data**, within one algorithm | How much the fit moves when the stations move → `suitability_sd` |

Both can be on. When they are, each member carries its own resample
interval, those replicates are pooled in proportion to member weight,
and the algorithm disagreement is reported on top in its own column — so
a projection carries both without either standing in for the other.

### Comparing two runs, and knowing when you cannot

Two runs come back with two numbers — ROC AUC 0.854 against 0.892 — and
nothing in either says whether that gap is a difference between the
models or a difference between the stations the survey happened to
visit.
[`compare_runs()`](https://camilleross.org/taupatch/reference/compare_runs.md)
answers that, from the held-out predictions each run already stores, so
it refits nothing:

``` r

rf   <- fit_patch_model(dat, rf_config)
gam  <- fit_patch_model(dat, gam_config)
weak <- fit_patch_model(dat, no_ocean_config)   # jday only, no SST or SSS

compare_runs(list(rf = rf, gam = gam, weak = weak))
#>   comparison reference_score comparison_score difference   lower   upper
#> 1        gam           0.854            0.892     0.0384  0.0141  0.0627
#> 2       weak           0.854            0.654    -0.1997 -0.2964 -0.1030
#>   p_value detectable n_stations
#> 1 0.01177     0.0325        684
#> 2 0.00458     0.1294        684
```

The first run in the list is the reference; every other is compared
against it, and `difference` is *comparison minus reference*, so a
positive number means the comparison won.

**`detectable` is the column that stops a null result being misread.**
It is the smallest true difference this comparison would have found, at
80% power — a property of the design rather than of the models. “Not
significant” on its own conflates *these two models perform alike* with
*this survey could not have told them apart*, and this separates them. A
comparison that cannot see anything below 0.13 has not shown that a 0.03
gap is absent.

The test is paired fold by fold, using the same Nadeau–Bengio correction
as the [jackknife](#testing-which-covariates-earn-their-place) and for
the same reason. It is two-sided here: leaving a covariate out has a
direction worth testing against, but asking which of two models is
better does not.

Runs are matched on the station index, not on row order. Two runs with
different covariates drop different stations to missingness, so the
comparison uses the stations both actually scored and **warns** with the
count — a run that drops many is telling you something.

**How many stations would settle it?**
[`power_curve()`](https://camilleross.org/taupatch/reference/power_curve.md)
refits at several subsample sizes and traces power against `n`:

``` r

power_curve(dat, list(full = config, starved = starved),
            fractions = c(0.25, 0.5, 1), replicates = 3)
#>   fraction n_stations replicates difference std_err df power detectable
#> 1     0.25        171          3     -0.316  0.1169  4 0.428      0.434
#> 2     0.50        342          3     -0.267  0.0893  4 0.632      0.332
#> 3     1.00        684          3     -0.272  0.0339  4 1.000      0.126
```

The curve is the artefact, not any point on it. Power against sample
size is steeply non-linear, and where a study sits on that curve is what
decides whether another season of sampling is worth it: a comparison at
0.43 is one survey away from being decisive, one at 1.00 will not be
improved by more stations.

Everything is refitted at every size — a model trained on half the
stations is a different model, not the same one evaluated on fewer — so
this is the expensive function here, and it parallelises over the whole
grid. Both runs see the same subsample and the same folds at every
point, which is what keeps the comparison paired all the way down.

Two honest limits. The target difference defaults to the one observed on
the full data, which is an estimate rather than a truth; if the observed
gap is itself mostly noise, the curve is answering a question about a
size that may not be real. And these are differences in a bounded
metric, so the normal-theory interval behind `detectable` is an
approximation that gets worse as AUC approaches 1.

### Training and projection windows

These are separate. Fitting on a long history and projecting a shorter
or later period is the normal case. Covariates are fetched for the union
of the two:

``` yaml
dates:                        # observations the model is fitted on
  years: [2003, 2017]
  months: [1, 12]
projection:                   # months that get mapped; omit to reuse the above
  years: [2018, 2020]
  months: [1, 12]
```

### How far to trust a map

A projection is a surface of point estimates, and a point estimate
invites more confidence than it has earned. `projection.uncertainty`
adds two layers that say where not to:

``` yaml
projection:
  uncertainty: true           # or the block below, to change the defaults
```

``` yaml
projection:
  uncertainty:
    method: folds             # or: bootstrap
    replicates: 200           # bootstrap only
    level: 0.9                # interval width
    novelty: true
```

They answer different questions, and a cell can fail one and pass the
other:

| Layer | The question it answers |
|----|----|
| `suitability_sd`, `suitability_lower`, `suitability_upper` | How much would this probability move if the training data had been slightly different? |
| `novelty`, `novel_variable` | Is this cell even in the range the model was trained on — and if not, which covariate put it outside? |

**The spread** comes from predicting each month with every model
cross-validation already fitted. Those models exist either way and are
normally discarded, so the ensemble is free; the cost is the extra
prediction passes, which is why this is off by default. It works
identically for all four model types, the same model-agnostic choice the
package makes for variable importance, so a forest’s interval and a
GAM’s mean the same thing and can be compared.

**The novelty surface** is the MESS of Elith et al. (2010). It runs to
100 at the median of the training data, falls toward 0 near the edge of
it, and **goes negative outside it** — `-50` means half a training range
beyond the edge. Those cells are extrapolation, and the model has no
evidence for what it says there. `novel_variable` names the covariate
responsible, which is the actionable half: “this shelf is extrapolated
because its chlorophyll is higher than any station saw” is a decision
about widening the training window, where a bare warning is not.

Read both, because **agreement between ensemble members is not
evidence**. They were all trained on the same data and can walk off the
end of it together, so a narrow interval over a novel cell is the one
combination that looks reassuring and is not. The two are drawn as
separate panels for that reason rather than blended into a single
“confidence” layer.

Two honest limits. The interval is a percentile range over members, not
a calibrated confidence interval — with `folds` there are only
`model.cv_folds` of them, and ten members cannot support a 95% interval,
which is why `level` defaults to 0.9 and `bootstrap` exists. And the
point estimate is not guaranteed to land inside it: it comes from the
model fitted on all the data and the interval from models fitted on
parts, so they are different quantities. On the mock run a 90% interval
contains it for about 90% of cells, which is the behaviour to expect.

### Reading the evaluation

`evals.csv` names the cutoff each metric belongs to, because the answer
changes a lot with it:

| metric    | threshold | value | std_err | lower | upper |
|-----------|-----------|-------|---------|-------|-------|
| roc_auc   |           | 0.857 | 0.027   | 0.803 | 0.897 |
| pr_auc    |           | 0.357 |         | 0.262 | 0.483 |
| sens      | 0.500     | 0.200 | 0.025   | 0.109 | 0.304 |
| spec      | 0.500     | 0.968 | 0.010   | 0.953 | 0.981 |
| tss       | 0.500     | 0.168 |         | 0.074 | 0.272 |
| precision | 0.500     | 0.394 |         | 0.231 | 0.568 |
| sens      | 0.051     | 0.862 |         | 0.732 | 0.966 |
| spec      | 0.051     | 0.740 |         | 0.655 | 0.872 |
| tss       | 0.051     | 0.601 |         | 0.547 | 0.712 |
| precision | 0.051     | 0.258 |         | 0.200 | 0.413 |

`tss` is the true skill statistic, `sens + spec - 1`, which is the
accuracy measure Allouche et al. (2006) recommend for presence/absence
models because, unlike kappa, it does not vary with prevalence.

**The two uncertainty columns are not two estimates of the same thing.**
`std_err` is the spread across cross-validation folds, so only the
metrics `tune` averages per fold have one — `pr_auc`, `tss` and
`precision` are computed from the pooled held-out predictions, which
uses the fold structure up, and those rows are blank. `lower` and
`upper` come from bootstrapping those pooled predictions and are present
on every row. One asks how much the number moves when the model is
refitted; the other asks how much it moves if the survey had sampled
different stations. A metric can be stable under one and not the other.

The bootstrap **re-derives the optimal cutoff inside each resample**
rather than holding it at the reported value. The cutoff is estimated
from the same predictions it then scores, so freezing it would report
the bottom four rows as more certain than they are. `threshold.yaml`
carries the cutoff’s own interval for the same reason — worth reading
before trusting a binarised map to it.

`model.bootstrap` sets the number of resamples, default 2000; `false`
turns the interval columns off and leaves them empty. It costs a few
seconds.

Two things this makes visible that a single-column table hides:

- **0.5 is the wrong cutoff here.** With only a tenth of stations
  patches, a random forest at 0.5 calls almost nothing a patch.
  Sensitivity reads 0.26, against 0.87 at the TSS-optimal cutoff. The
  model is far better than the default numbers suggest. Use
  `classification_threshold` from `threshold.yaml` when binarising a
  projection. That is what the original was reaching for with biomod2’s
  `metric.binary = 'ROC'`.
- **ROC AUC flatters an imbalanced problem.** 0.876 looks strong, but PR
  AUC is 0.433. ROC’s false-positive rate has the large non-patch class
  in its denominator. Precision is the question a patch map actually
  poses, and the trade-off is real. Moving to the optimal cutoff raises
  sensitivity to 0.87 but drops precision to 0.30. This is the argument
  of Saito & Rehmsmeier (2015), and of Sofaer et al. (2019) for rare
  events in species distribution models specifically — which is exactly
  what a patch is.

`diagnostics/` holds the curves these come from, and
`cv_predictions.csv` the held-out predictions, so any metric not
tabulated here can be computed without refitting.

## Outputs

Each run writes to `paths.output_dir`:

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
    diagnostics/gam_smooths.png        gam only, with fancyfx: fitted smooths with error bands
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

## Repository layout

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

## Citation

The paper this model comes from:

> Ross CH, Runge JA, Roberts JJ, Brady DC, Tupper B, Record NR (2023).
> Estimating North Atlantic right whale prey based on *Calanus
> finmarchicus* thresholds. *Marine Ecology Progress Series* 703:1–16.
> [doi:10.3354/meps14204](https://doi.org/10.3354/meps14204)

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

`citation("taupatch")` returns this entry along with one for the
software itself. Cite the paper for the method and the package for the
implementation, and see [References](#references) below for the data and
methods a particular run leans on.

## References

taupatch is mostly plumbing between other people’s data and other
people’s methods, and the obligation to cite travels with those rather
than with this package. **Cite whichever of these your run actually
used** — the groupings below are meant to make that easy to work out.
Each function’s own [`?help`](https://rdrr.io/r/utils/help.html) carries
the references relevant to it, and
[`covariate_info()`](https://camilleross.org/taupatch/reference/covariate_info.md)
names the source of every covariate at runtime.

### The model this implements

- Ross CH, Runge JA, Roberts JJ, Brady DC, Tupper B, Record NR (2023).
  Estimating North Atlantic right whale prey based on *Calanus
  finmarchicus* thresholds. *Marine Ecology Progress Series* **703**,
  1–16. [doi:10.3354/meps14204](https://doi.org/10.3354/meps14204)
- Elith J, Leathwick JR (2009). Species distribution models: ecological
  explanation and prediction across space and time. *Annual Review of
  Ecology, Evolution, and Systematics* **40**, 677–697.
  [doi:10.1146/annurev.ecolsys.110308.120159](https://doi.org/10.1146/annurev.ecolsys.110308.120159)
- Thuiller W, Lafourcade B, Engler R, Araújo MB (2009). BIOMOD – a
  platform for ensemble forecasting of species distributions.
  *Ecography* **32**(3), 369–373.
  [doi:10.1111/j.1600-0587.2008.05742.x](https://doi.org/10.1111/j.1600-0587.2008.05742.x)
  — the framework the archived `original/` pipeline was built on,
  replaced here by tidymodels

### Station data

Not distributed with this package. A run on the NOAA export should cite
it:

- NOAA National Marine Fisheries Service, Northeast Fisheries Science
  Center. *Zooplankton and ichthyoplankton abundance and distribution in
  the North Atlantic collected by the Ecosystem Monitoring (EcoMon)
  Project*. NOAA National Centers for Environmental Information, NCEI
  Accession 0187513.
  <https://www.ncei.noaa.gov/archive/accession/0187513>

### Environmental covariates

Fetched through [datamatch](https://github.com/chross22/datamatch),
whose [reference list](https://github.com/chross22/datamatch#references)
is the complete one for the data sources. The three products this
package’s catalog draws on:

- **Global Ocean Physics Reanalysis** (GLORYS12V1) — `SST`, `SSS`,
  `BOTT`, `UO`, `VO`, `SSH`, `MLD`, `SIC`. E.U. Copernicus Marine
  Service Information.
  [doi:10.48670/moi-00021](https://doi.org/10.48670/moi-00021)
- **Global Ocean Colour** (Copernicus-GlobColour) — satellite `CHL`,
  `PP`, `DIATO`, `DINO`. E.U. Copernicus Marine Service Information.
  [doi:10.48670/moi-00281](https://doi.org/10.48670/moi-00281)
- **Global Ocean Biogeochemistry Hindcast** — `NO3`, `PO4`, `O2`, `PH`,
  `CHL_MODEL`, `NPP_MODEL`. E.U. Copernicus Marine Service Information.
  [doi:10.48670/moi-00019](https://doi.org/10.48670/moi-00019)
- E.U. Copernicus Marine Service. *Copernicus Marine Toolbox*
  (`copernicusmarine`). <https://toolbox-docs.marine.copernicus.eu/> —
  how the above are downloaded. Mercator Ocean International publishes
  no DOI for the toolbox itself, so credit it by name; the citation that
  matters is the product’s.

Seafloor terrain, for `covariates.bathymetry`:

- NOAA National Centers for Environmental Information (2022). *ETOPO
  2022 15 Arc-Second Global Relief Model*.
  [doi:10.25921/fd45-gt74](https://doi.org/10.25921/fd45-gt74)
- Pante E, Simon-Bouhet B (2013). marmap: A package for importing,
  plotting and analyzing bathymetric and topographic data in R. *PLoS
  ONE* **8**(9), e73051.
  [doi:10.1371/journal.pone.0073051](https://doi.org/10.1371/journal.pone.0073051)

Climate indices, when `covariates.climate` is set, come from
[datamatch](https://github.com/chross22/datamatch#climate-indices); two
of the six (`LCR`, `AMOC`) are the published output of specific work and
are cited there.

### Derived covariates

Computed by [derivoce](https://github.com/chross22/derivoce), whose
[reference list](https://github.com/chross22/derivoce#references) is the
complete one. The methods behind the steps this README shows:

- Belkin IM, O’Reilly JE (2009). An algorithm for oceanic front
  detection in chlorophyll and SST satellite imagery. *Journal of Marine
  Systems* **78**(3), 319–326.
  [doi:10.1016/j.jmarsys.2008.11.018](https://doi.org/10.1016/j.jmarsys.2008.11.018)
  — `distance_to_front`
- d’Ovidio F, Fernández V, Hernández-García E, López C (2004). Mixing
  structures in the Mediterranean Sea from finite-size Lyapunov
  exponents. *Geophysical Research Letters* **31**(17).
  [doi:10.1029/2004GL020328](https://doi.org/10.1029/2004GL020328) —
  `fsle`
- Haller G (2015). Lagrangian coherent structures. *Annual Review of
  Fluid Mechanics* **47**, 137–162.
  [doi:10.1146/annurev-fluid-010313-141322](https://doi.org/10.1146/annurev-fluid-010313-141322)
  — `ftle`, `fsle`

Coastlines for `distance_to_shore` are [Natural
Earth](https://www.naturalearthdata.com/), public domain, via
`rnaturalearth`.

### Transformations

- Box GEP, Cox DR (1964). An analysis of transformations. *Journal of
  the Royal Statistical Society: Series B* **26**(2), 211–252.
  [doi:10.1111/j.2517-6161.1964.tb00553.x](https://doi.org/10.1111/j.2517-6161.1964.tb00553.x)
  — `boxcox`
- Field JG, Clarke KR, Warwick RM (1982). A practical strategy for
  analysing multispecies distribution patterns. *Marine Ecology Progress
  Series* **8**, 37–52.
  [doi:10.3354/meps008037](https://doi.org/10.3354/meps008037) — the
  fourth root as the plankton standard
- Yeo I-K, Johnson RA (2000). A new family of power transformations to
  improve normality or symmetry. *Biometrika* **87**(4), 954–959.
  [doi:10.1093/biomet/87.4.954](https://doi.org/10.1093/biomet/87.4.954)
  — `yeojohnson`

### Models

- Araújo MB, New M (2007). Ensemble forecasting of species
  distributions. *Trends in Ecology & Evolution* **22**(1), 42–47.
  [doi:10.1016/j.tree.2006.09.010](https://doi.org/10.1016/j.tree.2006.09.010)
  — why an ensemble of algorithms rather than a chosen best one
- Breiman L (2001). Random forests. *Machine Learning* **45**(1), 5–32.
  [doi:10.1023/A:1010933404324](https://doi.org/10.1023/A:1010933404324)
  — `rf`, and the origin of permutation importance
- Chen T, Guestrin C (2016). XGBoost: a scalable tree boosting system.
  *Proceedings of the 22nd ACM SIGKDD International Conference on
  Knowledge Discovery and Data Mining*, 785–794.
  [doi:10.1145/2939672.2939785](https://doi.org/10.1145/2939672.2939785)
  — the `brt` engine
- Elith J, Leathwick JR, Hastie T (2008). A working guide to boosted
  regression trees. *Journal of Animal Ecology* **77**(4), 802–813.
  [doi:10.1111/j.1365-2656.2008.01390.x](https://doi.org/10.1111/j.1365-2656.2008.01390.x)
- Friedman JH (2001). Greedy function approximation: a gradient boosting
  machine. *Annals of Statistics* **29**(5), 1189–1232.
  [doi:10.1214/aos/1013203451](https://doi.org/10.1214/aos/1013203451) —
  `brt`, and the partial dependence plot
- Hastie T, Tibshirani R (1986). Generalized additive models.
  *Statistical Science* **1**(3), 297–310.
  [doi:10.1214/ss/1177013604](https://doi.org/10.1214/ss/1177013604) —
  `gam`
- Marmion M, Parviainen M, Luoto M, Heikkinen RK, Thuiller W (2009).
  Evaluation of consensus methods in predictive species distribution
  modelling. *Diversity and Distributions* **15**(1), 59–69.
  [doi:10.1111/j.1472-4642.2008.00491.x](https://doi.org/10.1111/j.1472-4642.2008.00491.x)
  — the ensemble combination rules, compared against each other
- Marra G, Wood SN (2011). Practical variable selection for generalized
  additive models. *Computational Statistics & Data Analysis* **55**(7),
  2372–2387.
  [doi:10.1016/j.csda.2011.02.004](https://doi.org/10.1016/j.csda.2011.02.004)
  — `select_features` and the `ts` basis
- McCullagh P, Nelder JA (1989). *Generalized Linear Models*, 2nd
  edition. Chapman and Hall.
  [doi:10.1007/978-1-4899-3242-6](https://doi.org/10.1007/978-1-4899-3242-6)
  — `glm`
- Wood SN (2011). Fast stable restricted maximum likelihood and marginal
  likelihood estimation of semiparametric generalized linear models.
  *Journal of the Royal Statistical Society: Series B* **73**(1), 3–36.
  [doi:10.1111/j.1467-9868.2010.00749.x](https://doi.org/10.1111/j.1467-9868.2010.00749.x)
  — `model.method`
- Wood SN (2017). *Generalized Additive Models: An Introduction with R*,
  2nd edition. Chapman and Hall/CRC.
  [doi:10.1201/9781315370279](https://doi.org/10.1201/9781315370279) —
  the `mgcv` reference
- Wright MN, Ziegler A (2017). ranger: a fast implementation of random
  forests for high dimensional data in C++ and R. *Journal of
  Statistical Software* **77**(1), 1–17.
  [doi:10.18637/jss.v077.i01](https://doi.org/10.18637/jss.v077.i01) —
  the `rf` engine

### Evaluation and diagnostics

- Allouche O, Tsoar A, Kadmon R (2006). Assessing the accuracy of
  species distribution models: prevalence, kappa and the true skill
  statistic (TSS). *Journal of Applied Ecology* **43**(6), 1223–1232.
  [doi:10.1111/j.1365-2664.2006.01214.x](https://doi.org/10.1111/j.1365-2664.2006.01214.x)
  — `tss`, and the cutoff that maximises it
- Bengio Y, Grandvalet Y (2004). No unbiased estimator of the variance
  of k-fold cross-validation. *Journal of Machine Learning Research*
  **5**, 1089–1105. <https://jmlr.org/papers/v5/grandvalet04a.html> —
  why the jackknife’s test needs a variance correction rather than a
  better estimator
- Bouckaert RR, Frank E (2004). Evaluating the replicability of
  significance tests for comparing learning algorithms. *Advances in
  Knowledge Discovery and Data Mining* (PAKDD 2004), Lecture Notes in
  Computer Science **3056**, 3–12. Springer. — the correction applied to
  k-fold specifically. Listed without its DOI on purpose: a Springer
  chapter identifier contains an underscore, which the citation
  checker’s DOI pattern reads as the end of the identifier
- Dietterich TG (1998). Approximate statistical tests for comparing
  supervised classification learning algorithms. *Neural Computation*
  **10**(7), 1895–1923.
  [doi:10.1162/089976698300017197](https://doi.org/10.1162/089976698300017197)
  — the inflated Type I error of the uncorrected paired test
- Elith J, Phillips SJ, Hastie T, Dudík M, Chee YE, Yates CJ (2011). A
  statistical explanation of MaxEnt for ecologists. *Diversity and
  Distributions* **17**(1), 43–57.
  [doi:10.1111/j.1472-4642.2010.00725.x](https://doi.org/10.1111/j.1472-4642.2010.00725.x)
  — the leave-one-out / only-one jackknife pair
- Nadeau C, Bengio Y (2003). Inference for the generalization error.
  *Machine Learning* **52**(3), 239–281.
  [doi:10.1023/A:1024068626366](https://doi.org/10.1023/A:1024068626366)
  — the variance correction behind the jackknife’s `p_value` and
  [`compare_runs()`](https://camilleross.org/taupatch/reference/compare_runs.md)
- Hoenig JM, Heisey DM (2001). The abuse of power: the pervasive fallacy
  of power calculations for data analysis. *The American Statistician*
  **55**(1), 19–24.
  [doi:10.1198/000313001300339897](https://doi.org/10.1198/000313001300339897)
  — why
  [`compare_runs()`](https://camilleross.org/taupatch/reference/compare_runs.md)
  reports a minimum detectable difference rather than the “observed
  power” it is often confused with
- Fisher A, Rudin C, Dominici F (2019). All models are wrong, but many
  are useful: learning a variable’s importance by studying an entire
  class of prediction models simultaneously. *Journal of Machine
  Learning Research* **20**(177), 1–81.
  <https://jmlr.org/papers/v20/18-760.html> — permutation importance as
  a model-agnostic quantity, which is what makes it comparable across
  the four types
- Saito T, Rehmsmeier M (2015). The precision-recall plot is more
  informative than the ROC plot when evaluating binary classifiers on
  imbalanced datasets. *PLoS ONE* **10**(3), e0118432.
  [doi:10.1371/journal.pone.0118432](https://doi.org/10.1371/journal.pone.0118432)
  — `pr_auc`
- Elith J, Kearney M, Phillips S (2010). The art of modelling
  range-shifting species. *Methods in Ecology and Evolution* **1**(4),
  330–342.
  [doi:10.1111/j.2041-210X.2010.00036.x](https://doi.org/10.1111/j.2041-210X.2010.00036.x)
  — the multivariate environmental similarity surface behind `novelty`
- Sofaer HR, Hoeting JA, Jarnevich CS (2019). The area under the
  precision-recall curve as a performance metric for rare binary events.
  *Methods in Ecology and Evolution* **10**(4), 565–577.
  [doi:10.1111/2041-210X.13140](https://doi.org/10.1111/2041-210X.13140)

### Software this is built on

- Chang W, Cheng J, Allaire JJ, Sievert C, Schloerke B, Xie Y, Allen J,
  McPherson J, Dipert A, Borges B. *shiny: Web Application Framework for
  R*.
  [doi:10.32614/CRAN.package.shiny](https://doi.org/10.32614/CRAN.package.shiny)
  —
  [`run_taupatch_app()`](https://camilleross.org/taupatch/reference/run_taupatch_app.md),
  with `leaflet` and `shinyFiles`
- Garnier S, Ross N, Rudis R, Camargo AP, Sciaini M, Scherer C.
  *viridisLite: Colorblind-Friendly Color Maps (Lite Version)*.
  [doi:10.32614/CRAN.package.viridisLite](https://doi.org/10.32614/CRAN.package.viridisLite)
  — the magma scale used throughout, from the colormaps designed for
  matplotlib by Stéfan van der Walt and Nathaniel Smith
- Hijmans RJ. *terra: Spatial Data Analysis*.
  [doi:10.32614/CRAN.package.terra](https://doi.org/10.32614/CRAN.package.terra)
  — the projection rasters
- Kuhn M, Wickham H (2020). *Tidymodels: a collection of packages for
  modeling and machine learning using tidyverse principles*.
  <https://www.tidymodels.org> — `parsnip`, `recipes`, `rsample`,
  `tune`, `workflows`, `yardstick`
- Pebesma E (2018). Simple features for R: standardized support for
  spatial vector data. *The R Journal* **10**(1), 439–446.
  [doi:10.32614/RJ-2018-009](https://doi.org/10.32614/RJ-2018-009) —
  `sf`
- Wickham H (2016). *ggplot2: Elegant Graphics for Data Analysis*.
  Springer.
  [doi:10.1007/978-3-319-24277-4](https://doi.org/10.1007/978-3-319-24277-4)

[`citation()`](https://rdrr.io/r/utils/citation.html) works on any of
the R packages above.
