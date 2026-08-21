# Member weights from member scores

Proportional to the score, over the qualifying members only, and summing
to one. A non-qualifying member's weight is zero rather than absent, so
the summary table shows what it would have been given.

## Usage

``` r
ensemble_weights(scores, qualifies, metric = "tss")
```

## Arguments

- scores:

  one score per member

- qualifies:

  which members cleared `min_score`

- metric:

  which metric the scores are on

## Value

a numeric vector of weights, summing to 1

## Details

TSS runs from -1 to 1 and a negative score is a member predicting worse
than chance, so weights are floored at zero — a member cannot be given
negative influence, which would make the ensemble deliberately invert
it.
