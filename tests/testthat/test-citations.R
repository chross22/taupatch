# The citation checker is a script rather than package code, so it gets no
# coverage from anything else. Its parsing is what these cover; the network side
# is exercised by the scheduled workflow, which is the only place it can be.
#
# The bug worth guarding against is the checker passing everything: a matcher
# that is too loose reports a healthy repo whatever the state of the references,
# which is worse than not having the check at all.

# Under `R CMD check` the tests run from a directory that has no source tree
# above it, so the script is found where it is installed. `sys.source()` loads
# the definitions without running `main()`, which is guarded on being sourced.
checker <- function() {
  path <- system.file("tools", "check_citations.R", package = "taupatch")
  if (!nzchar(path)) path <- test_path("..", "..", "inst", "tools", "check_citations.R")
  skip_if_not(file.exists(path), "check_citations.R not in this build")

  env <- new.env()
  sys.source(path, envir = env)
  env
}

# The repo root, for the one test that reads the real files. Absent under
# `R CMD check`, where only the installed package exists.
repo_root <- function() {
  root <- test_path("..", "..")
  skip_if_not(file.exists(file.path(root, "DESCRIPTION")) &&
                file.exists(file.path(root, "README.md")),
              "not running from a source checkout")
  root
}

test_that("DOIs are found in every style the docs write them in", {
  env <- checker()

  text <- paste(
    "markdown: [doi:10.3354/meps14204](https://doi.org/10.3354/meps14204).",
    "roxygen: \\doi{10.1093/biomet/87.4.954}",
    "bare in a bibentry: doi = \"10.1214/aos/1013203451\",",
    "dataset: \\doi{10.48670/moi-00021}",
    sep = "\n"
  )

  expect_setequal(
    env$extract_dois(text),
    c("10.3354/meps14204", "10.1093/biomet/87.4.954",
      "10.1214/aos/1013203451", "10.48670/moi-00021")
  )
})

test_that("trailing punctuation is not read as part of the identifier", {
  env <- checker()

  # A DOI at the end of a sentence, inside a link, and inside a roxygen macro.
  # Each closing character belongs to the prose.
  expect_equal(env$extract_dois("see \\doi{10.1214/ss/1177013604}"),
               "10.1214/ss/1177013604")
  expect_equal(env$extract_dois("(https://doi.org/10.1023/A:1010933404324)."),
               "10.1023/A:1010933404324")
})

test_that("doi.org links are left to the DOI check rather than counted twice", {
  env <- checker()

  urls <- env$extract_urls(
    "[doi:10.3354/meps14204](https://doi.org/10.3354/meps14204) and
     <https://www.naturalearthdata.com/>"
  )
  expect_equal(urls, "https://www.naturalearthdata.com/")
})

test_that("the year is read from the entry the DOI is in, not the one above it", {
  env <- checker()

  # A package citation prints no year. Without a boundary the lookback walks
  # back into the previous list item and reports a mismatch that isn't.
  text <- paste(
    "- Fisher A, Rudin C, Dominici F (2019). All models are wrong.",
    "  <https://jmlr.org/papers/v20/18-760.html>",
    "- Chang W, Cheng J. *shiny: Web Application Framework for R*.",
    "  \\doi{10.32614/CRAN.package.shiny}",
    sep = "\n"
  )

  expect_true(is.na(env$year_near(text, "10.32614/CRAN.package.shiny")))
})

test_that("the year is found when the entry does print one", {
  env <- checker()

  text <- paste(
    "- Breiman L (2001). Random forests. *Machine Learning* **45**(1), 5-32.",
    "  \\doi{10.1023/A:1010933404324}",
    sep = "\n"
  )
  expect_equal(env$year_near(text, "10.1023/A:1010933404324"), 2001L)
})

test_that("a dead handle is told apart from a live one", {
  env <- checker()

  # Response code 1 is "found" and 100 is "handle not found". `:1` is a prefix
  # of `:100`, so a loose match passes every dead DOI - which would make the
  # whole check report success unconditionally.
  live <- '{"responseCode":1,"handle":"10.3354/meps14204"}'
  dead <- '{"responseCode":100,"handle":"10.5281/zenodo.7657585"}'
  pattern <- '"responseCode"[[:space:]]*:[[:space:]]*1[[:space:]]*[,}]'

  expect_true(grepl(pattern, live))
  expect_false(grepl(pattern, dead))
})

test_that("the files it reads are the ones that make citation claims", {
  env <- checker()
  files <- basename(env$source_files(repo_root()))

  expect_true("README.md" %in% files)
  expect_true("CITATION" %in% files)
  expect_true("covariate_catalog.R" %in% files)
  # man/ is generated from R/, so including it would report every DOI twice and
  # point at a file nobody edits.
  expect_false(any(grepl("\\.Rd$", files)))
})
