## ---------------------------------------------------------------------------
## public_spec.R  (private step: run in the private repository)
##
## Turns the detailed aggregate spec (synthetic/spec/, written by
## extract_spec.R from the participant data and never published) into the
## coarser public spec (synthetic/spec_public/), which is the ONLY input from
## the participant data that the public generator (generate.R) uses and that
## is published:
##
##   - numeric variables: quantiles q05 ... q95 only (no minimum/maximum),
##     plus the theoretical scale bounds where known
##   - correlations: dummies of groups with fewer than PUB_MIN_GROUP
##     participants (in either class) are left out
##   - text lengths: all languages together, quantiles q00 ... q95 only (no
##     upper 5%), plus the number of responses per language
##   - no file metadata (sizes, line counts), no SPSS codebook, no names of
##     variables with missing values
##
## Run from the repository root:  Rscript synthetic/public_spec.R
## ---------------------------------------------------------------------------

SPEC_IN       <- "synthetic/spec"
SPEC_OUT      <- "synthetic/spec_public"
PUB_MIN_GROUP <- 20
DATASETS      <- c("APEQ", "GCMQ", "PTSD")

## a count stored as text ("645", "<10", ">220") -> number (NA if suppressed)
as_count <- function(x) suppressWarnings(as.numeric(x))

coarsen_numeric <- function(x) {
  q <- x$quantiles
  list(n = x$n, digits = x$digits, grid = x$grid, scale = x$scale,
       quantiles = q[!names(q) %in% c("q00", "q100")], na_share = x$na_share)
}

## size of the smaller class of a dummy "<variable>=<level>"
dummy_group_size <- function(dummy, categorical, N) {
  var <- sub("=.*", "", dummy)
  lev <- sub("^[^=]*=", "", dummy)
  tab <- categorical[[var]]$table
  if (is.null(tab)) return(NA_real_)
  n <- as_count(tab$n[tab$level == lev])
  if (length(n) != 1 || is.na(n)) return(NA_real_)
  min(n, N - n)
}

coarsen_correlation <- function(cr, categorical) {
  vars  <- cr$variables
  dummy <- grepl("=", vars)
  size  <- vapply(vars, function(v) {
    if (!grepl("=", v)) return(Inf)
    dummy_group_size(v, categorical, cr$n)
  }, numeric(1))
  keep <- !dummy | (!is.na(size) & size >= PUB_MIN_GROUP)
  ## a principal submatrix of a positive definite matrix stays positive definite
  m <- cr$matrix[keep, keep]
  stopifnot(min(eigen(m, only.values = TRUE)$values) > 0)
  list(variables = vars[keep], n = cr$n, note = cr$note, basis = cr$basis,
       matrix = m,
       dummies = cr$dummies[cr$dummies$dummy %in% vars[keep], , drop = FALSE],
       left_out = c(vars[!keep], cr$excluded))
}

coarsen_text <- function(text) {
  types <- unique(sub(" .*", "", names(text)))
  setNames(lapply(types, function(t) {
    all <- text[[paste(t, "all")]]
    q   <- all$nchar$quantiles
    langs <- grep(paste0("^", t, " (?!all)"), names(text), value = TRUE, perl = TRUE)
    list(response = t, n = all$n, n_empty = all$n_empty,
         n_by_language = setNames(vapply(langs, function(l) text[[l]]$n, numeric(1)),
                                  sub(".* ", "", langs)),
         nchar_quantiles = q[!names(q) %in% "q100"])
  }), types)
}

public_spec <- function(s) {
  flow <- s$flow
  flow$predictors_with_missing_values <- NULL
  list(
    dataset     = s$dataset,
    note        = paste("Aggregate statistics only, coarsened for publication by",
                        "synthetic/public_spec.R (no min/max, no groups <", PUB_MIN_GROUP,
                        "in correlations, no upper 5% of text lengths)."),
    flow        = flow,
    raw_columns = s$raw_columns,
    raw_codes   = s$raw_codes,
    text_column_patterns = s$text_column_patterns,
    notes       = s$notes[!grepl("physical lines|lines containing", s$notes)],
    numeric     = lapply(s$numeric, coarsen_numeric),
    categorical = s$categorical,
    correlation = coarsen_correlation(s$correlation, s$categorical),
    text        = coarsen_text(s$text)
  )
}

## --- readable markdown ------------------------------------------------------------
md_table <- function(df) {
  df[] <- lapply(df, function(x) gsub("\\|", "/", as.character(x)))
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")), "")
}

write_md <- function(p, file) {
  out <- c(paste("# Public aggregate spec:", p$dataset), "", p$note, "",
           "## Sample flow", "")
  out <- c(out, sprintf("- %s: %s", names(p$flow),
                        vapply(p$flow, function(x) paste(x, collapse = ", "), character(1))), "")
  out <- c(out, "## Notes on the raw file format", "", paste("-", p$notes), "")
  out <- c(out, "## Raw columns", "", md_table(p$raw_columns))
  out <- c(out, "## Numeric variables (quantiles q05-q95)", "")
  num <- do.call(rbind, lapply(names(p$numeric), function(v) {
    x <- p$numeric[[v]]
    data.frame(variable = v, n = x$n, scale = paste(x$scale, collapse = "-"),
               na = x$na_share, quantiles = paste(x$quantiles, collapse = " "))
  }))
  out <- c(out, md_table(num))
  out <- c(out, "## Categorical variables", "")
  for (v in names(p$categorical)) {
    out <- c(out, paste0("**", v, "** (N = ", p$categorical[[v]]$N, ")"), "",
             md_table(p$categorical[[v]]$table))
  }
  cr <- p$correlation
  out <- c(out, "## Correlation matrix (normal scores)", "", cr$note, "",
           paste("Left out:", paste(cr$left_out, collapse = ", ")), "")
  m <- formatC(cr$matrix, format = "f", digits = 2)
  out <- c(out, md_table(data.frame(variable = rownames(m), m, check.names = FALSE)))
  out <- c(out, "## Text lengths (characters, quantiles q00-q95)", "")
  tx <- do.call(rbind, lapply(p$text, function(t) {
    data.frame(response = t$response, n = t$n, empty = t$n_empty,
               languages = paste(names(t$n_by_language), t$n_by_language, collapse = ", "),
               quantiles = paste(t$nchar_quantiles, collapse = " "))
  }))
  out <- c(out, md_table(tx))
  writeLines(enc2utf8(out), file, useBytes = TRUE)
}

dir.create(SPEC_OUT, showWarnings = FALSE)
for (d in DATASETS) {
  p <- public_spec(readRDS(file.path(SPEC_IN, paste0(d, ".rds"))))
  saveRDS(p, file.path(SPEC_OUT, paste0(d, ".rds")))
  write_md(p, file.path(SPEC_OUT, paste0(d, ".md")))
  message(d, ": ", length(p$correlation$variables), " variables in the correlation matrix; left out: ",
          paste(p$correlation$left_out, collapse = ", "))
}
