# Model types a run can fit

The original fitted one thing. These four are the ones a habitat
suitability study actually chooses between, and they disagree in ways
worth seeing: if a GLM and a random forest rank the same stations, the
relationships are close to monotonic and the forest is not buying much;
if they disagree sharply, either the response is genuinely non-linear or
the forest is fitting noise.

## Usage

``` r
model_types()
```

## Value

a named list, one entry per type, each with `label`, `engine`,
`package`, `description`, `tunable`, `needs_formula`, and `spec`

## Details

Each entry names a `parsnip` model function and the engine behind it.
`tunable` lists the hyperparameters `model.tune` will search — a GLM has
none, which is a property of the model rather than an omission.

## References

Breiman L (2001). Random forests. *Machine Learning* **45**(1), 5-32.
[doi:10.1023/A:1010933404324](https://doi.org/10.1023/A%3A1010933404324)
— `rf`

Wright MN, Ziegler A (2017). ranger: a fast implementation of random
forests for high dimensional data in C++ and R. *Journal of Statistical
Software* **77**(1), 1-17.
[doi:10.18637/jss.v077.i01](https://doi.org/10.18637/jss.v077.i01) — the
`rf` engine

Friedman JH (2001). Greedy function approximation: a gradient boosting
machine. *Annals of Statistics* **29**(5), 1189-1232.
[doi:10.1214/aos/1013203451](https://doi.org/10.1214/aos/1013203451) —
`brt`

Elith J, Leathwick JR, Hastie T (2008). A working guide to boosted
regression trees. *Journal of Animal Ecology* **77**(4), 802-813.
[doi:10.1111/j.1365-2656.2008.01390.x](https://doi.org/10.1111/j.1365-2656.2008.01390.x)

Chen T, Guestrin C (2016). XGBoost: a scalable tree boosting system.
*Proceedings of the 22nd ACM SIGKDD International Conference on
Knowledge Discovery and Data Mining*, 785-794.
[doi:10.1145/2939672.2939785](https://doi.org/10.1145/2939672.2939785) —
the `brt` engine

McCullagh P, Nelder JA (1989). *Generalized Linear Models*, 2nd edition.
Chapman and Hall.
[doi:10.1007/978-1-4899-3242-6](https://doi.org/10.1007/978-1-4899-3242-6)
— `glm`

Hastie T, Tibshirani R (1986). Generalized additive models. *Statistical
Science* **1**(3), 297-310.
[doi:10.1214/ss/1177013604](https://doi.org/10.1214/ss/1177013604) —
`gam`

Wood SN (2017). *Generalized Additive Models: An Introduction with R*,
2nd edition. Chapman and Hall/CRC.
[doi:10.1201/9781315370279](https://doi.org/10.1201/9781315370279) — the
`mgcv` reference

## See also

[`build_model_spec()`](https://camilleross.org/taupatch/reference/build_model_spec.md),
which turns a config into a fitted-ready spec

## Examples

``` r
names(model_types())
#> [1] "rf"  "brt" "glm" "gam"
model_types()$gam$description
#> [1] "A smooth function of each predictor, added together. The middle ground: it bends where the data says to, and because each term is a curve you can plot, it says what shape it found - which a forest cannot. Set `select_features: true` to let it shrink a useless term to zero."
vapply(model_types(), function(m) m$engine, character(1))
#>        rf       brt       glm       gam 
#>  "ranger" "xgboost"     "glm"    "mgcv" 
```
