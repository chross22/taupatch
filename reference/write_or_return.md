# Write a plot to disk or return it

Write a plot to disk or return it

## Usage

``` r
write_or_return(plot, path, width = 7, height = 5)
```

## Arguments

- plot:

  a ggplot object

- path:

  where to write, or `NULL` to return the plot

- width, height:

  PNG dimensions in inches

## Value

the plot, or `path` invisibly
