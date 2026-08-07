#!/usr/bin/env Rscript

# Check that every citation in the repo still points where it says it does.
#
# References rot in three ways, and this catches all three:
#
#   1. A DOI is mistyped, or was never right. It resolves to nothing, or worse,
#      to a different paper than the one named next to it.
#   2. A dataset DOI is superseded. Copernicus revises products and NCEI extends
#      accessions; the old identifier stops resolving.
#   3. A plain link dies. Documentation pages move more often than papers do.
#
# From a checkout:
#
#   Rscript inst/tools/check_citations.R
#
# From an installed copy, against whatever repo you are standing in:
#
#   Rscript -e 'source(system.file("tools/check_citations.R", package = "taupatch")); main()'
#
# Needs network access and the `curl` command; nothing else, deliberately, so it
# can run before the package's dependencies are installed and can be dropped
# into a sibling repo unchanged. `.github/workflows/citations.yaml` runs it
# monthly, so a reference that goes stale is noticed without anyone rereading
# the README.

# --- what to read ------------------------------------------------------------

# Everything that makes a citation claim. Generated man/ pages are skipped: they
# are built from the roxygen in R/, so checking both would report every DOI
# twice and blame the wrong file.
source_files <- function(root = ".") {
  paths <- c(
    file.path(root, "README.md"),
    file.path(root, "DESCRIPTION"),
    file.path(root, "inst", "CITATION"),
    list.files(file.path(root, "docs"), "\\.md$", full.names = TRUE),
    list.files(file.path(root, "R"), "\\.R$", full.names = TRUE),
    list.files(file.path(root, "vignettes"), "\\.Rmd$", full.names = TRUE),
    list.files(file.path(root, "inst", "shiny"), "\\.R$", full.names = TRUE)
  )
  paths[file.exists(paths)]
}

read_text <- function(path) {
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

# --- pulling references out of prose -----------------------------------------

# Trailing punctuation belongs to the sentence rather than to the identifier.
# A closing bracket is the common one, since these mostly sit inside markdown
# links and roxygen \doi{} macros.
strip_trailing <- function(x) sub("[.,;:'\")\\]}>]+$", "", x)

matches <- function(text, pattern) {
  found <- regmatches(text, gregexpr(pattern, text, perl = TRUE))[[1]]
  unique(strip_trailing(found))
}

extract_dois <- function(text) {
  matches(text, "10\\.[0-9]{4,9}/[^\\s\"'<>)\\]}]+")
}

extract_urls <- function(text) {
  urls <- matches(text, "https?://[^\\s\"'<>)\\]}]+")
  # doi.org links are checked as DOIs, through the handle system, which does not
  # care whether the publisher is blocking robots today.
  urls <- urls[!grepl("^https?://(dx\\.)?doi\\.org/", urls)]
  # Not real destinations: the loopback the app serves on, and the badge/action
  # URLs GitHub rewrites.
  urls[!grepl("^https?://(127\\.0\\.0\\.1|localhost)", urls)]
}

# The year the reference containing this DOI prints, which is what gets checked
# against the registry. It is the last year in parentheses before the DOI.
#
# The lookback stops at the start of the entry - a markdown list item, or a blank
# roxygen line - because otherwise a reference that prints no year picks up the
# year of the one above it and gets reported as a mismatch that isn't. Package
# citations legitimately have no year, and `NA` here means "nothing to compare".
year_near <- function(text, doi) {
  at <- regexpr(doi, text, fixed = TRUE)
  if (at < 0) return(NA_integer_)

  before <- substr(text, max(1, at - 600), at)
  boundary <- gregexpr("\n- |\n\n|\n#' *\n|\n#+ ", before)[[1]]
  boundary <- boundary[boundary > 0]
  if (length(boundary) > 0) {
    before <- substring(before, boundary[length(boundary)])
  }

  years <- regmatches(before, gregexpr("\\((1[89][0-9]{2}|20[0-9]{2})\\)", before))[[1]]
  if (length(years) == 0) return(NA_integer_)
  as.integer(gsub("[()]", "", years[length(years)]))
}

# --- asking the internet ------------------------------------------------------

# The body goes to a file and the status code to stdout, rather than both to
# stdout with a separator. curl's -w format is a shell argument, and anything
# involving a newline in it has to survive system2's re-quoting - which it does
# not, silently, by producing no output at all.
curl_get <- function(url, head_only = FALSE, timeout = 30) {
  body_file <- tempfile("citation")
  on.exit(unlink(body_file), add = TRUE)

  args <- c("-sL", "--max-time", timeout,
            "-A", shQuote("taupatch-citation-check (https://github.com/chross22/taupatch)"),
            "-o", shQuote(body_file),
            "-w", shQuote("%{http_code}"))
  if (head_only) args <- c(args, "-I")

  out <- suppressWarnings(
    system2("curl", c(args, shQuote(url)), stdout = TRUE, stderr = FALSE)
  )
  status <- suppressWarnings(as.integer(paste(out, collapse = "")))
  body <- if (!head_only && file.exists(body_file)) {
    paste(readLines(body_file, warn = FALSE), collapse = "\n")
  } else {
    ""
  }
  list(status = if (is.na(status)) 0L else status, body = body)
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || is.na(x)) y else x

# The DOI handle system, not the publisher. It answers for every registrar -
# Crossref for the papers, DataCite for the Copernicus and NCEI entries - and it
# does not serve a bot wall, so a refusal here means something real.
#
# Response code 1 is "found" and 100 is "handle not found", so the digit has to
# be anchored: `:1` is a prefix of `:100`, and matching loosely turns every dead
# DOI into a passing one. That is exactly the failure this script exists to
# catch, so it must not be the failure the script has.
#
# Retried once, since a transient refusal is otherwise indistinguishable from a
# real one and would report every DOI in the repo as unreachable.
# A handle that does not exist answers 404 with a perfectly good body saying so,
# so the body is what is read - on 404 as much as on 200. Treating a 404 as
# "could not reach the registry" would downgrade every dead DOI to a warning.
doi_registered <- function(doi, attempts = 2) {
  url <- paste0("https://doi.org/api/handles/", utils::URLencode(doi, TRUE))
  for (attempt in seq_len(attempts)) {
    res <- curl_get(url)
    if (res$status %in% c(200L, 404L) && nzchar(res$body)) {
      return(grepl('"responseCode"[[:space:]]*:[[:space:]]*1[[:space:]]*[,}]', res$body))
    }
    if (attempt < attempts) Sys.sleep(2)
  }
  NA
}

# Crossref knows the journal articles and books. It does not know the dataset
# DOIs, and a 404 from it is not a problem - only a mismatch is.
crossref_year <- function(doi) {
  res <- curl_get(paste0("https://api.crossref.org/works/",
                         utils::URLencode(doi, TRUE),
                         "?mailto=camille.ross@maine.edu"))
  if (res$status != 200) return(NA_integer_)
  parts <- regmatches(res$body,
                      regexpr('"issued":\\{"date-parts":\\[\\[[0-9]{4}', res$body))
  if (length(parts) == 0) return(NA_integer_)
  as.integer(sub(".*\\[\\[", "", parts))
}

# Some publishers refuse HEAD, and some refuse anything without a browser. A
# 403 or 429 is the site declining to talk to a script, which is not evidence
# the page is gone, so it is reported separately from a real 404.
url_status <- function(url) {
  status <- curl_get(url, head_only = TRUE)$status
  if (status %in% c(0L, 403L, 405L, 429L, 501L)) status <- curl_get(url)$status
  status
}

# --- the check ----------------------------------------------------------------

collect <- function(files) {
  dois <- list()
  urls <- list()
  for (path in files) {
    text <- read_text(path)
    for (doi in extract_dois(text)) {
      dois[[doi]] <- c(dois[[doi]], path)
      attr(dois[[doi]], "year") <- attr(dois[[doi]], "year") %||% year_near(text, doi)
    }
    for (url in extract_urls(text)) urls[[url]] <- c(urls[[url]], path)
  }
  list(dois = dois, urls = urls)
}

main <- function() {
  found <- collect(source_files())
  failures <- character()
  warnings <- character()

  cat("Checking", length(found$dois), "DOIs and", length(found$urls),
      "links.\n\n")

  for (doi in names(found$dois)) {
    where <- paste(unique(basename(found$dois[[doi]])), collapse = ", ")
    registered <- doi_registered(doi)

    if (isTRUE(registered)) {
      claimed <- attr(found$dois[[doi]], "year")
      actual <- crossref_year(doi)
      # Online-first and reprints make the registered year differ from the one a
      # reference prints, legitimately. A gap of more than a year is worth a look
      # but is not a broken citation.
      if (!is.na(claimed) && !is.na(actual) && abs(claimed - actual) > 1) {
        warnings <- c(warnings, sprintf(
          "  %s (%s)\n    reference says %d, Crossref says %d",
          doi, where, claimed, actual))
        cat("?", doi, "- year mismatch\n")
      } else {
        cat("ok", doi, "\n")
      }
    } else if (is.na(registered)) {
      warnings <- c(warnings, sprintf("  %s (%s)\n    could not reach doi.org",
                                       doi, where))
      cat("?", doi, "- unreachable\n")
    } else {
      failures <- c(failures, sprintf("  %s (%s)\n    not registered with the DOI system",
                                       doi, where))
      cat("FAIL", doi, "\n")
    }
  }

  cat("\n")
  for (url in names(found$urls)) {
    where <- paste(unique(basename(found$urls[[url]])), collapse = ", ")
    status <- url_status(url)

    if (status >= 200 && status < 400) {
      cat("ok", url, "\n")
    } else if (status %in% c(0L, 403L, 429L)) {
      warnings <- c(warnings, sprintf("  %s (%s)\n    HTTP %d - blocked or unreachable, not necessarily gone",
                                       url, where, status))
      cat("?", url, "- HTTP", status, "\n")
    } else {
      failures <- c(failures, sprintf("  %s (%s)\n    HTTP %d", url, where, status))
      cat("FAIL", url, "- HTTP", status, "\n")
    }
  }

  cat("\n", strrep("-", 70), "\n", sep = "")
  if (length(warnings) > 0) {
    cat("\nWorth a look (", length(warnings), "):\n", sep = "")
    cat(paste(warnings, collapse = "\n"), "\n")
  }
  if (length(failures) > 0) {
    cat("\nBroken (", length(failures), "):\n", sep = "")
    cat(paste(failures, collapse = "\n"), "\n")
    cat("\nFix these in the file named beside each, and in the README's",
        "References section if it lists them too.\n")
    quit(status = 1)
  }

  cat("\nEvery citation resolves.\n")
  invisible(TRUE)
}

if (sys.nframe() == 0) main()
