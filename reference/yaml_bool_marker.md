# The marker that carries a boolean's source text through parsing

A prefix rather than an attribute or a class, because it has to survive
`yaml` collapsing a sequence of scalars into an atomic vector, which
drops attributes. `[true, false]` would otherwise come back as two
strings.

## Usage

``` r
yaml_bool_marker
```

## Details

Deliberately plain ASCII. The first version used control characters, on
the reasoning that nothing could collide with them. That was true, and
it made `file(1)` report the whole of `config.R` as binary rather than
as source, so editors and diff viewers presented the file as corrupt.

Spelling it out costs nothing. Only the boolean handlers ever prepend
this, and they only ever see scalars YAML itself resolved as booleans —
a quoted `"true"` carries no boolean tag and is never marked. The one
way left to collide is a config value that genuinely begins with this
text.
