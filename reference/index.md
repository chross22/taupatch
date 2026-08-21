# Package index

## Running a study

A study is a config file plus data. Point-and-click through the Shiny
app or drive the same pipeline from YAML; both take the same route.

- [`compare_runs()`](https://camilleross.org/taupatch/reference/compare_runs.md)
  : Is the gap between two model runs real?
- [`generate_config()`](https://camilleross.org/taupatch/reference/generate_config.md)
  : Write a taupatch run config
- [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)
  : Load and validate a taupatch run config
- [`pipeline_stages()`](https://camilleross.org/taupatch/reference/pipeline_stages.md)
  : The stages a run passes through, and how far along each one is
- [`run_taupatch()`](https://camilleross.org/taupatch/reference/run_taupatch.md)
  : Run the full taupatch pipeline
- [`run_taupatch_app()`](https://camilleross.org/taupatch/reference/run_taupatch_app.md)
  : Launch the taupatch Shiny app
- [`save_config()`](https://camilleross.org/taupatch/reference/save_config.md)
  : Write a config list to a YAML file
- [`single_stages()`](https://camilleross.org/taupatch/reference/single_stages.md)
  : Individually resolved life stages

## Zooplankton data

Reading plankton counts and getting them into one shape. A patch is
defined by a species-and-stage abundance threshold, so which stages a
column holds matters as much as the number in it.

- [`abundance_units()`](https://camilleross.org/taupatch/reference/abundance_units.md)
  : The count and the unit a suffix encodes
- [`available_species()`](https://camilleross.org/taupatch/reference/available_species.md)
  : Species a formatted database could model
- [`available_stages()`](https://camilleross.org/taupatch/reference/available_stages.md)
  : List the life stages a database holds for a species
- [`default_species_catalog()`](https://camilleross.org/taupatch/reference/default_species_catalog.md)
  : Default species catalog
- [`format_zoop_data()`](https://camilleross.org/taupatch/reference/format_zoop_data.md)
  : Build a station database from a raw zooplankton export
- [`is_raw_export()`](https://camilleross.org/taupatch/reference/is_raw_export.md)
  : Whether a header is a raw export rather than a station database
- [`label_patch()`](https://camilleross.org/taupatch/reference/label_patch.md)
  : Label high-abundance patches
- [`load_zoop_data()`](https://camilleross.org/taupatch/reference/load_zoop_data.md)
  : Load zooplankton station data
- [`measurement_columns()`](https://camilleross.org/taupatch/reference/measurement_columns.md)
  : In-situ measurement columns the raw export carries
- [`raw_abundance_suffix()`](https://camilleross.org/taupatch/reference/raw_abundance_suffix.md)
  : The abundance suffix a raw export uses
- [`species_catalog_from()`](https://camilleross.org/taupatch/reference/species_catalog_from.md)
  : A species catalog for the taxa in a raw export
- [`split_dates()`](https://camilleross.org/taupatch/reference/split_dates.md)
  : Split a date column into year, month, and day
- [`stage_suffix_pattern()`](https://camilleross.org/taupatch/reference/stage_suffix_pattern.md)
  : The suffix marking a life stage on a taxon column
- [`station_summary()`](https://camilleross.org/taupatch/reference/station_summary.md)
  : Summary of a station dataset
- [`taxon_shorthand()`](https://camilleross.org/taupatch/reference/taxon_shorthand.md)
  : Conventional shorthand for a taxon name
- [`validate_columns()`](https://camilleross.org/taupatch/reference/validate_columns.md)
  : Check the config's declared columns against the CSV header
- [`zoop_taxa()`](https://camilleross.org/taupatch/reference/zoop_taxa.md)
  : Taxon columns in a raw zooplankton export

## Covariates

Fetching environmental fields and joining them to stations, including
the derived layers that come from derivoce.

- [`add_derivoce_covariates()`](https://camilleross.org/taupatch/reference/add_derivoce_covariates.md)
  : Add the configured derived covariates to the covariate grid
- [`apply_prejoin_steps()`](https://camilleross.org/taupatch/reference/apply_prejoin_steps.md)
  : Apply the configured pre-join steps to the fetched products
- [`attach_covariates()`](https://camilleross.org/taupatch/reference/attach_covariates.md)
  : Attach covariates to zooplankton stations
- [`bathymetry_covariates()`](https://camilleross.org/taupatch/reference/bathymetry_covariates.md)
  : Static seafloor covariates
- [`climate_index_covariates()`](https://camilleross.org/taupatch/reference/climate_index_covariates.md)
  : Climate indices selectable as covariates
- [`copernicus_client()`](https://camilleross.org/taupatch/reference/copernicus_client.md)
  : Locate the Copernicus Marine client
- [`copernicus_covariates()`](https://camilleross.org/taupatch/reference/copernicus_covariates.md)
  : Catalog of selectable environmental covariates
- [`covariate_grid()`](https://camilleross.org/taupatch/reference/covariate_grid.md)
  : Build the covariate grid for one month
- [`covariate_info()`](https://camilleross.org/taupatch/reference/covariate_info.md)
  : Covariate reference table
- [`covariate_monthly_means()`](https://camilleross.org/taupatch/reference/covariate_monthly_means.md)
  : Average each covariate over the study area, per month and year
- [`covariate_transforms()`](https://camilleross.org/taupatch/reference/covariate_transforms.md)
  : Covariate transformations available in the recipe
- [`default_copernicus_datasets()`](https://camilleross.org/taupatch/reference/default_copernicus_datasets.md)
  : Default Copernicus datasets
- [`derivoce_choices()`](https://camilleross.org/taupatch/reference/derivoce_choices.md)
  : Derived covariates offerable for a given covariate selection
- [`derivoce_covariates()`](https://camilleross.org/taupatch/reference/derivoce_covariates.md)
  : Derived covariates computed from the covariate grid
- [`derivoce_required_inputs()`](https://camilleross.org/taupatch/reference/derivoce_required_inputs.md)
  : Covariates a set of derived choices needs fetching
- [`derivoce_steps_for()`](https://camilleross.org/taupatch/reference/derivoce_steps_for.md)
  : Config steps for a set of chosen derived covariates
- [`fetch_covariates()`](https://camilleross.org/taupatch/reference/fetch_covariates.md)
  : Fetch environmental covariates
- [`generate_mock_covariates()`](https://camilleross.org/taupatch/reference/generate_mock_covariates.md)
  : Generate synthetic environmental covariates
- [`plot_covariate_annual()`](https://camilleross.org/taupatch/reference/plot_covariate_annual.md)
  : Plot a covariate's annual mean over the record
- [`plot_covariate_heatmap()`](https://camilleross.org/taupatch/reference/plot_covariate_heatmap.md)
  : Plot a month-by-year heatmap of a covariate
- [`plot_covariate_map()`](https://camilleross.org/taupatch/reference/plot_covariate_map.md)
  : Map one covariate for one month
- [`plot_covariate_seasonal()`](https://camilleross.org/taupatch/reference/plot_covariate_seasonal.md)
  : Plot a covariate's seasonal cycle, one line per year
- [`prejoin_steps()`](https://camilleross.org/taupatch/reference/prejoin_steps.md)
  : Per-covariate steps applied before products are joined

## Fitting and projecting

The models themselves, single or ensembled, and the projection of a
fitted model onto a new grid.

- [`ensemble_rules()`](https://camilleross.org/taupatch/reference/ensemble_rules.md)
  : Ways an ensemble can combine its members
- [`ensemble_settings()`](https://camilleross.org/taupatch/reference/ensemble_settings.md)
  : Multi-algorithm ensemble settings
- [`fit_patch_ensemble()`](https://camilleross.org/taupatch/reference/fit_patch_ensemble.md)
  : Fit an ensemble of model types on the same data
- [`fit_patch_model()`](https://camilleross.org/taupatch/reference/fit_patch_model.md)
  : Fit a patch habitat suitability model
- [`gam_bases()`](https://camilleross.org/taupatch/reference/gam_bases.md)
  : Spline bases mgcv offers for a smooth
- [`gam_methods()`](https://camilleross.org/taupatch/reference/gam_methods.md)
  : Smoothing parameter estimation methods mgcv offers
- [`gam_smooth_terms()`](https://camilleross.org/taupatch/reference/gam_smooth_terms.md)
  : Smooth terms of a fitted GAM
- [`glm_coefficients()`](https://camilleross.org/taupatch/reference/glm_coefficients.md)
  : Coefficients of a fitted logistic regression
- [`model_engine_fit()`](https://camilleross.org/taupatch/reference/model_engine_fit.md)
  : The underlying engine object from a fitted model
- [`model_types()`](https://camilleross.org/taupatch/reference/model_types.md)
  : Model types a run can fit
- [`partial_effects()`](https://camilleross.org/taupatch/reference/partial_effects.md)
  : Partial effect of each predictor on patch probability
- [`power_curve()`](https://camilleross.org/taupatch/reference/power_curve.md)
  : How the comparison would improve with more stations
- [`print(`*`<taupatch_ensemble>`*`)`](https://camilleross.org/taupatch/reference/print.taupatch_ensemble.md)
  : Print an ensemble
- [`project_patch_model()`](https://camilleross.org/taupatch/reference/project_patch_model.md)
  : Project a fitted model to monthly habitat suitability maps

## Uncertainty and validation

What the model does not know. Novelty and overlap surfaces say where a
projection is extrapolating rather than interpolating.

- [`bootstrap_evaluation()`](https://camilleross.org/taupatch/reference/bootstrap_evaluation.md)
  : Bootstrap intervals for the evaluation metrics
- [`jackknife_covariates()`](https://camilleross.org/taupatch/reference/jackknife_covariates.md)
  : Test every covariate by leaving it out, in parallel
- [`jackknife_dropped()`](https://camilleross.org/taupatch/reference/jackknife_dropped.md)
  : Which covariates a jackknife would drop
- [`jackknife_settings()`](https://camilleross.org/taupatch/reference/jackknife_settings.md)
  : Covariate jackknife settings
- [`novelty_surface()`](https://camilleross.org/taupatch/reference/novelty_surface.md)
  : How far outside the training data each cell sits
- [`thin_covariates()`](https://camilleross.org/taupatch/reference/thin_covariates.md)
  : Thin a covariate grid to a bounded number of cells
- [`uncertainty_settings()`](https://camilleross.org/taupatch/reference/uncertainty_settings.md)
  : Projection uncertainty settings

## Plots and output

Figures for inspecting each stage, and the raster stack written at the
end.

- [`plot_calibration()`](https://camilleross.org/taupatch/reference/plot_calibration.md)
  : Plot probability calibration
- [`plot_gam_smooths()`](https://camilleross.org/taupatch/reference/plot_gam_smooths.md)
  : Plot a GAM's fitted smooths, with fancyfx
- [`plot_glm_coefficients()`](https://camilleross.org/taupatch/reference/plot_glm_coefficients.md)
  : Plot logistic regression coefficients with their intervals
- [`plot_importance()`](https://camilleross.org/taupatch/reference/plot_importance.md)
  : Plot variable importance
- [`plot_partial_effects()`](https://camilleross.org/taupatch/reference/plot_partial_effects.md)
  : Plot partial effects, one panel per predictor
- [`plot_pr_curve()`](https://camilleross.org/taupatch/reference/plot_pr_curve.md)
  : Plot the precision-recall curve
- [`plot_projection()`](https://camilleross.org/taupatch/reference/plot_projection.md)
  : Plot a monthly habitat suitability projection
- [`plot_projection_uncertainty()`](https://camilleross.org/taupatch/reference/plot_projection_uncertainty.md)
  : Plot how far a monthly projection can be trusted
- [`plot_roc_curve()`](https://camilleross.org/taupatch/reference/plot_roc_curve.md)
  : Plot cross-validated ROC curves
- [`plot_station_map()`](https://camilleross.org/taupatch/reference/plot_station_map.md)
  : Map the stations, coloured by abundance
- [`plot_station_series()`](https://camilleross.org/taupatch/reference/plot_station_series.md)
  : Abundance over the record
- [`plot_threshold_performance()`](https://camilleross.org/taupatch/reference/plot_threshold_performance.md)
  : Plot performance across classification thresholds
- [`projection_map()`](https://camilleross.org/taupatch/reference/projection_map.md)
  : Build a leaflet map of a projection GeoTIFF
- [`write_suitability_stack()`](https://camilleross.org/taupatch/reference/write_suitability_stack.md)
  : Write the monthly projections as one multi-layer raster

## Test fixtures

Mock data, so an example or a test can run without a data extract.

- [`generate_mock_zoop_data()`](https://camilleross.org/taupatch/reference/generate_mock_zoop_data.md)
  : Generate a synthetic zooplankton database
