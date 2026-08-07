# Rebuilding the zooplankton tau-patch pipeline

## Context

This repo models "tau-patches" — high-abundance patches of a zooplankton species, defined
by a species-specific abundance threshold — and projects monthly spatial habitat
suitability maps. The code in `original/` is the version behind [Ross et al.
(2023)](https://doi.org/10.3354/meps14204): a `biomod2` ([Thuiller et al.
2009](https://doi.org/10.1111/j.1600-0587.2008.05742.x)) Random Forest trained on
EcoMon/CPR/MBON zooplankton stations joined to gridded environmental covariates, projected
month-by-month across the Northeast US shelf.

This document is about what changed and why. It cites work only where the change turns on
it; the full reference list for the package — data sources, model methods, metrics — is at
the bottom of the [README](../README.md#references).

It still describes the science we want, but the implementation has aged out from under it:

- **Environmental data is hardcoded to a server layout that no longer exists.**
  `original/load_covars.R` is ~200 lines of copy-pasted `raster::raster(file.path(...))`
  calls against HYCOM / GlobColour / CCMP / SRTM30 directory trees rooted at
  `/mnt/s1/projects/ecocast/...`. `original/get_climatology.R` repeats the same
  16-covariate `if (x %in% env_covars)` block **four times** — 185 lines to compute one
  climatology.
- **Species are hardcoded.** A three-branch if-else (`original/buildZoopModel.R:104-110`)
  maps `"cfin"`/`"ctyp"`/`"pseudo"` onto `<species>_total` columns. Adding a taxon means
  editing the modeling function.
- **The spatial join silently loses stations.** `original/format_model_data.R` rounds both
  zooplankton and covariate coordinates to 1 decimal place (lines 36-37, 59-60) and then
  does an *exact* `left_join` on the rounded values. Any station that doesn't land on a
  matching rounded covariate cell gets NA covariates and is later dropped by `na.exclude()`.
- **`biomod2` forces awkward workarounds.** A `setwd()` round-trip
  (`original/buildZoopModel.R:177-190`) because `BIOMOD_Modeling` writes to the working
  directory, and model runs selected by string-pasting
  (`paste0(species, version, "_allData_RUN", k, "_RF")`).
- **Latent bugs, some of which mean the file can't even be sourced:**
  - `original/buildZoopModel.R:158` — `next` called outside any loop. The
    "skip if too little data" guard *errors* instead of skipping.
  - `original/runCtypPercentileModel.R:60` — missing comma between arguments; the file
    does not parse.
  - `original/create_database.R:24` — uses `fp_ecomon` before it's defined (line 17
    defines `ecomon`).
  - `original/create_database.R:233` — NOAA records are tagged `dataset = "CPR"`, colliding
    with the actual CPR dataset, so the two can't be told apart downstream.
  - `original/format_model_data.R:85` — `readr::write_csv(path=)`, an argument removed
    from readr years ago.
  - `original/buildZoopModel.R:257` — `%>%` in a file that never attaches magrittr.

## Goals

1. **Generalizable** — any species, any covariate set, any region, driven by a config file
   rather than by editing functions.
2. **Simpler** — delete the covariate-loading and data-formatting boilerplate by delegating
   to [`chross22/datamatch`](https://github.com/chross22/datamatch) + Copernicus Marine.
3. **Modern** — `tidymodels` instead of `biomod2`; `terra` instead of the retired `raster`.
4. **Usable without writing R** — a Shiny GUI to select parameters, run models, and browse
   the resulting maps.

## Decisions made along the way

- **`original/` is archived unmodified**, not deleted, and excluded from the package build
  via `.Rbuildignore` — same treatment `msomgom` gave its `legacy/` folder. It's the record
  of what the published model did.
- **`taupatch` becomes a proper R package** (rather than `msomgom`'s flat-scripts + configs
  layout). The Shiny app ships in `inst/shiny/` and calls the package's own exported
  functions, so there's no duplicated pipeline logic behind the GUI.
- **One pooled model, projected monthly** — not twelve per-month models. This is what the
  original actually did (one RF over all months with day-of-year as a covariate, then
  `BIOMOD_Projection` per month/year), and it keeps all the training data in one fit.
  Per-month fitting would give each model ~1/12 the data and would trip the
  "≥100 rows and both classes present" guard in thin months.
- **`biomod2` is dropped entirely** in favor of [`tidymodels`](https://www.tidymodels.org)
  (Kuhn & Wickham 2020). Beyond removing the `setwd()`
  and string-pasting workarounds, `tidymodels` is engine-agnostic — swapping RF for boosted
  trees or a GLM becomes a config field, which is what the GUI wants to expose.
- **Copernicus replaces HYCOM/GlobColour/CCMP.** `datamatch::accessEnvDat()` fetches by
  product/dataset/variable IDs declared in config; `datamatch::matchData()` joins to
  station points with `sf::st_nearest_feature`, which removes the rounded-coordinate join
  and the station loss that came with it.
- **The threshold gains an explicit type.** The original encoded percentile-vs-absolute as
  a magic rule — `if (threshold < 1)` meant "treat as a percentile"
  (`original/buildZoopModel.R:144`), which quietly breaks for any real abundance threshold
  below 1. Config now says `threshold: {type: percentile|absolute, value: ...}`.
- **The real zooplankton data stays on the user's machine.** It is never copied into this
  repo or shared into a session. `data/` is gitignored, the config points at a local path,
  and all development and automated testing runs against synthetic mock data
  (`generate_mock_zoop_data()`).

### Input schema — derived from `original/create_database.R`, not guessed

The pipeline reads the database that `original/create_database.R` writes
(`zooplankton_database.csv`), so its schema is known from the code rather than needing to
inspect the real file. From the final assembly (`create_database.R:237-250`):

| Group | Columns |
|---|---|
| Identity / space / time | `station`, `year`, `month`, `day`, `lat`, `lon`, `dataset` |
| *C. finmarchicus* stages | `cfin_CI`, `cfin_CII`, `cfin_CIII`, `cfin_CIV`, `cfin_CV`, `cfin_CVI`, `cfin_CI_IV`, `cfin_CV_VI` |
| *C. typicus* stages | `ctyp_adult`, `ctyp_CIII`, `ctyp_CIV`, `ctyp_CV`, `ctyp_C`, `ctyp_IV_V`, `ctyp_IV_VI`, `ctyp_CVI`, `ctyp_CV_CVI` |
| *Pseudocalanus* stages | `pseudo_adult`, `pseudo_CII`, `pseudo_CV`, `pseudo_C`, `pseudo_CVI`, `pseudo_CI_IV` |
| Derived totals | `cfin_total`, `ctyp_total`, `pseudo_total` — `rowSums()` over `contains("<species>")` |

`dataset` takes values `ECOMON`, `ECOMON_STAGED`, `MBON`, `CPR` (note the NOAA-tagged-as-CPR
bug above), replacing the original's `biomod_dataset` argument with a config filter.

Two consequences for the design:

1. **The species catalog accepts either form.** A species can name an existing
   `abundance_column` (e.g. `ctyp_total`) *or* a `stage_prefix` (e.g. `ctyp`) that the
   pipeline sums across matching columns. The second option generalizes exactly what
   `create_database.R` hardcodes three times, so a new taxon with staged counts needs no
   code change.
2. **Column names remain config-declared and validated**, not assumed. `load_config()`
   checks them against the CSV header up front and reports precisely which are missing, so
   a database built slightly differently is a config edit rather than a debugging session.

### ECOMON is the default case

In practice this model runs on ECOMON data ~99.9% of the time, so every default is set for
ECOMON rather than treating all four source datasets as equally likely:

- `columns.dataset_filter` defaults to `[ECOMON]` (the original passed this as the
  `biomod_dataset` argument, and every real run script in `original/` set it to `"ECOMON"`).
- `study_area.bbox` defaults to the Northeast US shelf, matching the mask the original
  cropped projections to — `extent(-82.65, -55.95, 35, 47.99)`
  (`original/load_covars.R:147`).
- `generate_config()`'s defaults reproduce a working ECOMON run, so a new config is one
  call with a species name.

One ECOMON-specific detail worth recording, because it looks like a bug and isn't: the
ECOMON branch of `create_database.R` (lines 32-55) **zero-fills** every life stage ECOMON
doesn't resolve, rather than setting NA. So for ECOMON rows, `ctyp_total` collapses to
`ctyp_adult`, `cfin_total` to `cfin_CV_VI`, and `pseudo_total` to `pseudo_adult`. The
`rowSums()` totals are still correct, and `abundance_column: <species>_total` is the
simpler and preferred config for ECOMON. `stage_prefix` exists for datasets that genuinely
resolve stages (`ECOMON_STAGED`, `CPR`).

Because ECOMON zero-fills rather than NA-fills, a species with no ECOMON coverage at all
would produce a column of zeros rather than NAs — which `na.exclude()` would *not* catch,
and which would train a degenerate model. `label_patch()` guards this explicitly: a
constant or all-zero abundance column is an error with a clear message, not a silent
all-absent fit.

Note the original model read `zooplankton_covar_data` — the *output* of
`format_model_data.R` (database ⨝ covariates, one CSV per year). The rebuilt pipeline
regenerates covariates from Copernicus at run time, so it reads the database directly and
`format_model_data.R` / `bind_years.R` disappear.

### Life-stage selection

Added after the first working pipeline, so a run can model particular life stages
rather than only whole-species totals.

- **Stages are read from the database, not hardcoded.** Which stages exist differs
  per species — `cfin` resolves `CI` through `CVI`, while `ctyp` and `pseudo` carry
  `adult` plus only some copepodite stages. `available_stages()` reads them off the
  CSV header, so the app's picker and config validation always offer exactly what
  the data has.
- **Only individually resolved stages are selectable.** The database also holds
  combination columns spanning several stages (`ctyp_CV_CVI`, `pseudo_CI_IV`,
  `ctyp_IV_VI`, the unstaged `ctyp_C`). They overlap the single stages, so summing
  a mix would double-count.
- **`cfin_CV_VI` is presented as `adult`.** ECOMON does not resolve CV from CVI for
  *C. finmarchicus* and reports the combined count, which is the adult number.
  Selecting `adult` together with `CV` or `CVI` is rejected, since `cfin_CV_VI`
  already spans both.
- **Leaving `stages` empty sums every column, combination columns included**, which
  reproduces `<prefix>_total`. This is deliberate: it keeps the default ECOMON run
  working, because ECOMON reports `cfin` *only* in `cfin_CV_VI`, with the single
  stages zero-filled.

### Covariates are named, not coded

`covariates.selected` lists familiar names (`SST`, `CHL`, `MLD`, ...) that resolve
through `copernicus_covariates()` to a Copernicus product, dataset, and variable.
Covariates sharing a dataset are fetched in a single request, so selecting SST,
SSS, and MLD costs one download rather than three. Fetched columns are renamed to
the selected names, so model predictors read as `SST` rather than `thetao`.
`covariate_info()` tabulates every covariate with units and long name, and backs
the app's Covariates reference tab.

Copernicus revises dataset identifiers periodically; `covariates.copernicus`
remains available for raw product/dataset/variable specs the catalog does not cover.

### Training and projection windows are separate

`dates` selects the observations the model is fitted on; `projection.years` /
`projection.months` select the months that get mapped. Fitting on a long history
and projecting a shorter or later period is the normal case. `projection` defaults
to `dates`, so a config that does not distinguish them behaves as before. Covariates
are fetched for the *union* of the two windows, as two sets rather than one
spanning range, so a gap between distant windows is not downloaded.

## Target structure

```
DESCRIPTION, NAMESPACE, LICENSE
R/
  config.R        load_config(), generate_config()
  zoop_data.R     load_zoop_data(), label_patch()
  covariates.R    fetch_covariates(), attach_covariates(), covariate_grid()
  model.R         fit_patch_model()
  project.R       project_patch_model()
  plotting.R      plot_projection(), plot_importance()
  pipeline.R      run_taupatch()
  mock.R          generate_mock_zoop_data(), generate_mock_covariates()
  app.R           run_taupatch_app()
inst/
  configs/        ctyp_gom.yaml (real example), mock_test.yaml (fast smoke test)
  shiny/          Setup / Run / Results / Maps tabs
tests/testthat/
man/              roxygen-generated
original/         archived as-is, excluded via .Rbuildignore
docs/rebuild_plan.md
```

## What each original file becomes

| Original | Replacement |
|---|---|
| `load_covars.R` (~200 lines of hardcoded raster paths) | `datamatch::accessEnvDat()`, driven by `covariates.copernicus` in config |
| `int_chl.R`, `get_climatology.R` (185 lines, 4× repeated if-blocks) | dropped — Copernicus serves monthly products directly |
| `format_model_data.R` (nested loops, lossy rounded join) | `datamatch::matchData()` (`st_nearest_feature`, no rounding) |
| `bind_years.R` (rbind loop over per-year CSVs) | one source table + a `dplyr::filter()` |
| species if-else chain (`buildZoopModel.R:104-110`) | `species.catalog` in config (`abundance_column` or `stage_prefix`) |
| `biomod2` formatting / modeling / projection + `setwd()` | a `tidymodels` `workflow()` |
| `create_database.R`, `read_NOAA.R`, `data_mapping.R`, `latlon2cell.R` | stay in `original/` — they build the input database from raw sources, which is a separate concern from modeling |

## Modeling

- **Label** — `label_patch()` resolves the threshold (percentile via `quantile()`, or
  absolute) and produces a two-level factor. Keeps the original's ≥100-rows / both-classes
  guard, but as a real `stop()` with a useful message rather than a stray `next`.
- **Recipe** — `step_log()` on the config's `log_transform` columns (replacing the ad-hoc
  `log(abs(chl))` / `log(abs(int_chl))` / `log(abs(bat))` lines), `step_normalize()`,
  `step_naomit()`.
- **Spec** — `rand_forest() |> set_engine("ranger", importance = "permutation") |> set_mode("classification")`.
- **Resampling** — `vfold_cv(v = cv_folds, strata = patch)`, replacing biomod2's
  `CV.nb.rep = 10` / `data.split.perc = 70`.
- **Metrics** — `roc_auc`, `kap`, `sens`, `spec`, plus a custom TSS (`sens + spec - 1`,
  [Allouche et al. 2006](https://doi.org/10.1111/j.1365-2664.2006.01214.x)), matching the
  original's `c('ROC', 'TSS', 'KAPPA')`.
- **Tuning** — `tune_grid()` + `finalize_workflow()` only when `model.tune: true`.

Artifacts written per run: `model.rds`, `evals.csv`, `var_importance.csv` — the same
outputs the original produced, without biomod2's nested directory sprawl.

### Static seafloor covariates came back via marmap

The original's depth, slope, and distance-to-shore layers were SRTM30 files on a
dead server. Depth, slope, and aspect now come from NOAA ETOPO via
`marmap::getNOAA.bathy()`, cached into the run's output directory. They live under
their own `covariates.bathymetry` config key rather than `covariates.selected`,
because they are static — fetched once and attached to every month — and do not
come from Copernicus. Config validation points you at the right key if you list
one in the wrong place.

Two conversions matter: `marmap` returns elevation (land positive, depth
negative), so it is negated to give depth as a positive magnitude, matching the
original's `log(abs(bat))`; and land is masked to NA rather than left as negative
depth, which a model would otherwise read as very shallow water.

Distance to shore was **not** restored, and neither were the original's gradients
(`sst_grad`, `uv_grad`), time integrals (`int_chl`), or lags (`lag_sst`). Those
are derived quantities headed for a separate package.

### One blank map, one silent serialization bug

The app's leaflet map rendered as a blank grey box. The cause was subtle enough to
be worth recording: `terra::ext(r)[1]` returns a *named* numeric (`xmin`), and
`jsonlite` serializes a named vector as a JSON **object** rather than a scalar. So
`leaflet::fitBounds()` received `{"xmin": -70.1}` instead of `-70.1`, silently
failed to set a view, and left leaflet with no center or zoom — at which point it
requests no basemap tiles and positions no overlay. Nothing errored anywhere; the
only signal was a `asJSON(keep_vec_names=TRUE)` warning that looked like harmless
deprecation noise.

Fixed by `unname(as.vector(terra::ext(r)))`. The map building moved into
`projection_map()` in the package so it can be regression-tested — the test asserts
each bound is an unnamed length-1 number, which is what would have caught this.

## Bugs found in dependencies along the way

Two were in `chross22/datamatch`, and blocked the pipeline rather than being
incidental:

1. **Nothing was exported.** Both `accessEnvDat()` and `matchData()` had roxygen
   documentation but no `@export` tag, so `NAMESPACE` was empty and neither was
   callable from outside the package. Fixed by adding the tags.
2. **`matchData()` matched on YEAR/MONTH/DAY exactly**, which matches nothing
   against monthly products — a monthly mean carries one time step per month while
   observations fall on arbitrary days. Generalized to match at the environmental
   data's own temporal resolution (`day`/`month`/`year`, inferred from its time
   steps, overridable via `temporal_resolution`). Also fixed while there: an
   accumulator that only initialized on the chronologically first period (so an
   unsorted input errored outright), observations in periods with no environmental
   data being silently dropped rather than returned as NA, and environmental
   variables colliding with species column names being disambiguated inconsistently
   as `.x`/`.y`.

A third was environmental rather than a code bug: R source packages on this machine
were linking against **conda's** libraries, because miniconda precedes Homebrew on
`PATH`. `xml2` built against conda's `libxml2`/`libicuuc` and then failed to load
under Homebrew R. Building with conda removed from `PATH` links against the system
libraries and works. Worth knowing before debugging any future install failure here.

## Verification

1. `devtools::document()` + `devtools::check()` clean.
2. **Mock end-to-end, no network** — `run_taupatch()` on `inst/configs/mock_test.yaml` with
   `covariates.source: mock`, asserting a fitted workflow, ROC AUC meaningfully above 0.5
   (the mock data has planted spatial/seasonal structure), and one GeoTIFF + PNG per
   configured month/year.
3. **Unit tests** — percentile vs absolute thresholds; `stage_prefix` summing vs explicit
   `abundance_column`; config validation rejecting an unknown `species.active` and a
   missing column; `log_transform` applying only to named columns.
4. **One real run, by the user, locally** — small config (one species, two covariates, one
   year, three months, small bbox) against the real database and the live Copernicus API.
   Steps 1-3 cover every code path except reading the real file's header.

## Open items

- **Static covariates have no Copernicus equivalent.** Bathymetry, slope, distance-to-shore,
  and fetch were in the original covariate set but aren't Copernicus products. They need
  either a separate static raster source in config or to be dropped from the default
  covariate set. Decide once the first real run shows what the model actually needs.
- **`datamatch::matchData()` loops day-by-day and `rbind`s.** On a multi-decade station
  database that may be slow. If it bites, the fix belongs upstream in `datamatch`, not
  worked around here.

## Full plan

The approved plan with the complete config schema is at
`~/.claude/plans/elegant-percolating-hollerith.md` (local to the machine this was written
on; summarized here since it isn't part of this repo).
