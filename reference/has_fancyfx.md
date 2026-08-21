# Whether fancyfx is available to draw smooths

Its own function so the optional path can be exercised in tests without
mocking [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html)
itself, which every package that loads a graphics device also goes
through.

## Usage

``` r
has_fancyfx()
```

## Value

`TRUE` when fancyfx is installed

## It used to be called fancygam

The package was renamed when it grew past GAMs. The rename is why this
matters more than a find-and-replace: `chross22/fancygam` still resolves
on GitHub, so `Remotes: chross22/fancygam` kept installing — but what it
installs now declares `Package: fancyfx`, so
[`requireNamespace("fancygam")`](https://rdrr.io/r/base/ns-load.html)
returned `FALSE` on every fresh install and the smooth plots were
skipped in silence. Anyone with the old package still sitting in their
library saw nothing wrong.

That is the failure mode to watch for here: this function gates a
diagnostic rather than the run, so a wrong answer costs a plot and no
error.
