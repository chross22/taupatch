# Write the monthly projections as one multi-layer raster

The per-month GeoTIFFs are one file each, which is what a GIS wants and
awkward for anything that treats time as a dimension: a decade is a
hundred and eighty files whose only record of which month they are is
the filename. This stacks them into a single raster with one layer per
month, named for it.

## Usage

``` r
write_suitability_stack(projections, path)
```

## Arguments

- projections:

  the tibble
  [`project_patch_model()`](https://camilleross.org/taupatch/reference/project_patch_model.md)
  returns

- path:

  where to write the `.grd`

## Value

`path`, invisibly

## Details

Built from the files rather than from rasters held in memory. `terra`
reads a stack lazily, so a decade of a real grid is streamed from disk
to disk instead of being assembled in one piece first.

## Why .grd

It is `raster`'s native format and `terra` writes it, it keeps layer
names - which is the whole point here, since the names carry the dates -
and it has no band limit. GeoTIFF can hold the layers but not their
names, so a stacked `.tif` would come back as `suitability_1` through
`suitability_180`. Note that it is two files: a `.grd` header and a
`.gri` of data, and one is no use without the other.

One wrinkle worth knowing. `terra` writes a `.grd` header without
recording each layer's range, so
[`terra::minmax()`](https://rspatial.github.io/terra/reference/minmax.html)
on the result reports a placeholder of some 1e38 rather than the 0 to 1
a probability actually spans. The values are correct - they match the
GeoTIFFs cell for cell - and `terra::global(stack, range, na.rm = TRUE)`
gives the real range. Only a reader that trusts the header, such as an
automatic colour scale, is misled, and setting the range yourself is the
fix there.

## Examples

``` r
if (FALSE) { # \dontrun{
write_suitability_stack(result$projections, "suitability.grd")
} # }
```
