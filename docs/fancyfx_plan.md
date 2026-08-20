# Taking what fancyfx now offers

`fancyfx` has gone from 0.2.0 to 0.8.0 and now exports 26 functions, a good
number of which overlap what taupatch built for itself. This is the plan for
adopting it: what to take, what to leave, what becomes redundant, and the one
thing that cannot be taken as it stands.

Written against `fancyfx 0.8.0` (`d429991`) and taupatch 0.2.0 (`983cf55`).

## The finding that shapes everything else

**fancyfx's four evaluation plots cannot consume taupatch's cross-validated
predictions, and adopting them as they stand would replace honest diagnostics
with optimistic ones.**

This was worth checking rather than assuming, and the answer is not the one the
function signatures suggest. `plotROC()`, `plotThreshold()`, `plotImportance()`
and `plotCalibration()` all route through `fancyfx:::evaluation_pairs()`, which
does this and only this:

```r
observed  <- binary_response(model, newdata)
predicted <- predict_probability(model, newdata, ...)
```

There is no path to hand it predictions that already exist. It re-predicts,
always.

taupatch's ROC, threshold, calibration and PR curves are drawn from **pooled
out-of-fold predictions**: every station is scored by the one fold model that
never saw it, collected in `model$predictions` with `.row`, `id`, `patch` and
`.pred_patch`. That is cross-validated performance. Handing the final fitted
model and its own training stations to fancyfx instead produces something
different — and fancyfx knows it, which is to its credit:

* `evaluation_pairs()` warns: *"Evaluating on the data the model was fitted to.
  These metrics are optimistic and are not validation."*
* `in_sample_caption()` prints it onto the figure: *"In-sample: scored on the
  data the model was fitted to. Optimistic, and not validation."*

The `folds` argument does not rescue this. It splits the *scoring* of one
already-fitted model by fold; it does not make each fold's predictions come from
a model that held that fold out. On taupatch's data `is_training_data()` returns
`TRUE`, so every plot would carry the caption above.

A second, blunter obstacle sits on top of the first. taupatch fits through a
`recipes` workflow, so the engine's response is the baked `..y`, not `patch`.
Handing `model_data` to `threshold_metrics()` does not produce an optimistic
number — it errors outright:

```
newdata has no column '..y', the model's response.
```

So these four cannot be adopted **as fancyfx currently stands**. The fix is not
in taupatch, and it is not a workaround: it is a generalisation fancyfx wants
anyway.

### Upstream change 1: let evaluation take predictions

An entry point that accepts predictions rather than a model — the shape any
cross-validated workflow already has, taupatch included:

```r
threshold_metrics(observed = , predicted = , folds = )
```

`evaluation_pairs()` returns early when handed those, with `in.sample = FALSE`,
and every plot built on it works unchanged. This is the whole change. It costs
fancyfx nothing, it removes the `..y` problem along with the in-sample one, and
it makes fancyfx usable by *any* package that cross-validates rather than only
by ones that keep a single fitted model around.

Only with this in place do the four evaluation plots become a streamlining:
taupatch deletes four hand-built ggplots and keeps its out-of-fold numbers.
Without it they are a downgrade, and would not be worth taking.

## What to take now

### New capability — nothing in taupatch does these

| function | what it adds | why it belongs here |
|---|---|---|
| `spatial_sorting_bias()` | Hijmans (2012). How much of the AUC is an artefact of presences and absences being differently distributed in space | ECOMON stations are clustered along transects. A spatially sorted sample inflates AUC, and nothing in the current evaluation says by how much. This is a genuine gap |
| `niche_overlap()` | Schoener's *D* and Warren's *I* between two projected surfaces | taupatch models three species and can now compare runs. "Do *cfin* and *ctyp* occupy the same habitat?" and "do rf and gam draw the same map?" are the natural next questions, and `compare_runs()` deliberately answers neither — it compares performance, not surfaces |
| `niche_equivalency()` | A permutation test for whether two niches are the same | The inferential half of the above |

### Better versions of what exists

| function | replaces | why it is a clean swap |
|---|---|---|
| `plotUncertainty()` | the spread panel of `plot_projection_uncertainty()` | Takes a raster, not a model, so the in-sample problem does not arise. Adds `cv`/`range`/`iqr` beside `sd`, and `max.cells` downsampling, which the current panel needs on a real grid |
| `plotExtrapolation()` | the novelty panel of the same | Same. Adds `novel.only` |
| `comparePlots()` | nothing yet | Overlays several models' effect curves for one covariate — exactly the per-member view the new ensemble wants |
| `mess()` | `novelty_surface()` | The same method implemented twice. Requires upstream change 2 below |

### Upstream change 2: let mess() take a data frame, and name the culprit

`fancyfx::mess()` requires a `SpatRaster` and returns the surface alone:

```
Error: x must be a SpatRaster of covariates, not a <data.frame>.
```

taupatch's projections are data frames at that point in the pipeline, and its
`novelty_surface()` returns a second column — `novel_variable`, the predictor
that put the cell outside the training range. That column is the actionable
half: "this shelf is extrapolated" is a shrug, "extrapolated because its
chlorophyll is higher than any station saw" is a decision. It is used in the run
log, the projection CSV, and the plot subtitle.

Two small generalisations, then, and both make `mess()` better on its own terms:
accept a data frame as well as a raster, and return which variable was
responsible. With those, `novelty_surface()` deletes and taupatch calls
`mess()`.

### Deliberately not taken

Excluded by the "streamlining **and** improvement" test rather than by any fault
of theirs:

* **`thin_points()`** — spatial thinning changes which stations are modelled.
  That is a methodological decision for a study to make, not a default for a
  package to acquire, and it streamlines nothing here.
* **`calc_deviance()`** — defined for `glm` and `gam` and not for `rf` or
  `brt`. taupatch reports metrics that mean the same thing for all four types
  on purpose; a column that is `NA` for half of them works against that.
* **`plotHexbin()`** — the station map is not currently a problem worth a new
  code path.

## Redundancy assessment

To be done **after** the integration lands, against the code as it then stands,
not against this plan. The candidates, in the order they are worth examining:

1. **`novelty_surface()` against `fancyfx::mess()`.** These are the same method
   — the multivariate environmental similarity surface of Elith et al. (2010) —
   implemented twice. One should go. taupatch's returns `novel_variable`, the
   predictor responsible, which is the actionable half and must survive the
   merge whichever way it goes.
2. **`plot_projection_uncertainty()`** becomes a thin arrangement of two
   fancyfx panels rather than two hand-built ggplots.
3. **`ensemble_spread()` against `fancyfx::ensemble_summary()`.** Same
   statistics over a stack of member predictions. taupatch's returns a data
   frame aligned to the projection rows; fancyfx's takes a raster. Whether they
   can be one function depends on which side the alignment lives.
4. **`permutation_importance()`** — taupatch's is deliberately model-agnostic
   and computed by prediction so all four model types are comparable. fancyfx's
   takes `(model, newdata)` and has the same in-sample problem as the plots.
   Blocked with them, and possibly not worth merging even after.
5. **`plot_importance()`, `plot_calibration()`, `plot_roc_curve()`,
   `plot_threshold_performance()`** — not candidates. Their fancyfx
   counterparts answer a different question on different evidence.

The rule for the assessment: **a duplicate is only redundant if the replacement
answers the same question on the same evidence.** `mess()` and
`novelty_surface()` do. `plotROC()` and `plot_roc_curve()` currently do not,
because one is in-sample and the other is not, and that is a difference in what
the number means rather than in how it is drawn.

## The app

Into the existing **Diagnostics** tab rather than a new one, since that is where
a user already goes for this material:

* spatial sorting bias beside the evaluation table, with the one-line
  explanation of what a high value means for the AUC above it
* explained deviance in the same block
* the ensemble's per-member effect curves, via `comparePlots()`, when the run
  fitted an ensemble
* niche overlap between the active species and one other, when more than one has
  been run

The app must not gain a dependency the package does not have: `fancyfx` is a
Suggests, so every panel here is behind `has_fancyfx()` and degrades to the
current view without it.

## Order of work

Two of these are changes to fancyfx. They come first, because the taupatch side
of each is small and pointless without them.

**In fancyfx**

1. `threshold_metrics(observed=, predicted=, folds=)` — upstream change 1.
2. `mess()` on a data frame, returning the responsible variable — upstream
   change 2.

**In taupatch**

3. `plotUncertainty()` / `plotExtrapolation()` into
   `plot_projection_uncertainty()`. Needs nothing upstream; two hand-built
   ggplots delete.
4. `comparePlots()` for ensemble members.
5. `spatial_sorting_bias()` into the evaluation table.
6. `niche_overlap()` / `niche_equivalency()` as a projection comparison,
   alongside `compare_runs()`.
7. `novelty_surface()` replaced by `mess()`, once (2) lands.
8. The four evaluation plots replaced, once (1) lands.
9. App: Diagnostics tab.
10. Redundancy pass, against the code as it then stands.
The four evaluation plots are not on this list, and are not expected to join
it.

## References

Elith J, Kearney M, Phillips S (2010). The art of modelling range-shifting
species. *Methods in Ecology and Evolution* **1**(4), 330–342.
doi:10.1111/j.2041-210X.2010.00036.x — MESS

Hijmans RJ (2012). Cross-validation of species distribution models: removing
spatial sorting bias and calibration with a null model. *Ecology* **93**(3),
679–688. doi:10.1890/11-0826.1 — spatial sorting bias

Schoener TW (1968). The *Anolis* lizards of Bimini: resource partitioning in a
complex fauna. *Ecology* **49**(4), 704–726. doi:10.2307/1935534 — *D*

Warren DL, Glor RE, Turelli M (2008). Environmental niche equivalency versus
conservatism. *Evolution* **62**(11), 2868–2883.
doi:10.1111/j.1558-5646.2008.00482.x — *I*, and the equivalency test
