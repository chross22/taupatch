# Check a step's fields against the derivoce function it names

Deferred to run time rather than config validation, since it needs
derivoce itself and a config may be validated where derivoce is not
installed.

## Usage

``` r
check_derivoce_args(spec, fun)
```

## Arguments

- spec:

  a normalized step specification

- fun:

  the derivoce function the step names

## Value

`TRUE` invisibly; errors listing the accepted arguments otherwise
