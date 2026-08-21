# Generate a synthetic zooplankton database

Writes a CSV matching the schema `original/create_database.R` produces,
so the pipeline can be exercised end-to-end without the real survey
data, which stays on its owner's machine.

## Usage

``` r
generate_mock_zoop_data(config, n_stations = 400, seed = 42)
```

## Arguments

- config:

  a config list, as returned by
  [`load_config()`](https://camilleross.org/taupatch/reference/load_config.md)

- n_stations:

  number of station visits to generate per year

- seed:

  random seed

## Value

the path written, invisibly

## Details

Two details are copied from the real database's structure rather than
invented, because the pipeline's behavior depends on them:

- Stage columns that a survey does not resolve are filled with
  **zeros**, not NA (`create_database.R` lines 32-55 for ECOMON), so
  `<species>_total` collapses to the single stage ECOMON measures.

- `dataset` takes the values `ECOMON`, `ECOMON_STAGED`, `MBON`, `CPR`,
  so the config's `dataset_filter` is actually exercised rather than
  matching every row.

Abundance is given real spatial and seasonal structure — a
temperature-like gradient plus a summer peak — so a model fit to it
should score meaningfully better than chance. A smoke test that passed
on pure noise would not be testing anything.
