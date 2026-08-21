# taupatch: Spatial Habitat Suitability Models for Zooplankton High-Abundance Patches

Builds monthly spatial habitat suitability models for high-abundance
patches ("tau-patches") of a zooplankton species, where a patch is
defined by a species-specific abundance threshold. Zooplankton station
data is matched to Copernicus Marine environmental covariates via the
datamatch package, optionally extended with covariates derived from the
covariate grid - gradients, fronts, lags, and flow diagnostics - via the
derivoce package, classified against the threshold, and modeled with a
tidymodels workflow. Fitted models are projected to monthly habitat
suitability maps. Species, covariates, thresholds, study area, and model
settings are all driven by a YAML config rather than code edits. Rebuilt
from the biomod2-based pipeline of Ross et al. (2023).

## References

The model this implements:

Ross CH, Runge JA, Roberts JJ, Brady DC, Tupper B, Record NR (2023).
Estimating North Atlantic right whale prey based on *Calanus
finmarchicus* thresholds. *Marine Ecology Progress Series* **703**,
1-16. [doi:10.3354/meps14204](https://doi.org/10.3354/meps14204)

Most of what a run produces comes from someone else's data or someone
else's method, and the obligation to cite travels with those. Each
function's own help page carries the references relevant to it — see
[`copernicus_covariates()`](https://camilleross.org/taupatch/reference/copernicus_covariates.md)
and
[`bathymetry_covariates()`](https://camilleross.org/taupatch/reference/bathymetry_covariates.md)
for the data sources,
[`derivoce_covariates()`](https://camilleross.org/taupatch/reference/derivoce_covariates.md)
for the derived ones,
[`covariate_transforms()`](https://camilleross.org/taupatch/reference/covariate_transforms.md),
[`model_types()`](https://camilleross.org/taupatch/reference/model_types.md),
and
[`permutation_importance()`](https://camilleross.org/taupatch/reference/permutation_importance.md)
for the methods. The README's References section collects all of them in
one place, and `citation("taupatch")` gives this package's own entry.

## See also

Useful links:

- <https://github.com/chross22/taupatch>

- Report bugs at <https://github.com/chross22/taupatch/issues>

## Author

**Maintainer**: Camille Ross <camille.ross@maine.edu>
([ORCID](https://orcid.org/0000-0002-1428-2294))

Authors:

- Camille Ross <camille.ross@maine.edu>
  ([ORCID](https://orcid.org/0000-0002-1428-2294))
