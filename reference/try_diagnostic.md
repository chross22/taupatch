# Run a diagnostic, warning rather than failing the run

The model is already fitted and its outputs already written by this
point, so a diagnostic that cannot be produced should not throw the run
away. It should also not pass silently: an empty diagnostics directory
looks the same whether the plot failed or was never wanted.

## Usage

``` r
try_diagnostic(expr, what)
```

## Arguments

- expr:

  the diagnostic to attempt

- what:

  its name, for the warning

## Value

the result, or `NULL` with a warning
