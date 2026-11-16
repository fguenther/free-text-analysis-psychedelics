## ---------------------------------------------------------------------------
## synthetic/extract_spec.R
##
## Extracts AGGREGATE statistics from the real (private) data. They are the
## input of a generator that builds a synthetic dataset (Gaussian copula for
## the tabular variables, newly written free-text responses), so that the
## analysis pipeline in R/ can be published and run on non-personal data.
##
## Output, one pair per dataset (APEQ, GCMQ, PTSD):
##   synthetic/spec/<dataset>.rds   list with all statistics (see spec_* below)
##   synthetic/spec/<dataset>.md    the same, readable on its own
## Contents: sample flow, storage format of every raw column the pipeline
## reads, numeric marginals (21 quantiles), categorical level shares,
## normal-scores correlation matrix, text-length quantiles.
##
## Disclosure control (applied to everything written):
##   * no row-level data, no free text, no exact individual values
##   * counts of 1-9 participants are shown as "<10"; categorical levels with
##     < 10 participants are pooled into "other" (ordinal values: merged with
##     a neighbouring value)
##   * minimum/maximum: exact only if >= 10 participants share that value,
##     otherwise bottom-/top-coded at the 10th smallest/largest value
##   * dummies with < 10 participants in one of their classes are left out
##     of the correlation matrix
##   * exceptions: sample-flow numbers (including the PTSD exclusion counts),
##     most of which are reported in the manuscript
##
## Run from the repository root (needs data/raw/ and data/embeddings/):
##   Rscript synthetic/extract_spec.R
## Sources R/config.R, R/embed.R and R/datasets.R unchanged.
## ---------------------------------------------------------------------------

local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  if (length(f)) setwd(file.path(dirname(normalizePath(f)), ".."))
})
if (!file.exists("R/config.R")) stop("Run from the repository root.")

suppressPackageStartupMessages({
  source("R/config.R")
  source("R/embed.R")
  source("R/datasets.R")
  library(Matrix)
})

MIN_CELL <- 10L                 # smallest count shown exactly
EMB      <- "e5"                # embeddings are only needed to build the samples
PROBS    <- seq(0, 1, by = 0.05)
OUT_DIR  <- file.path("synthetic", "spec")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)


## ===========================================================================
## disclosure-safe summaries
## ===========================================================================

show_n <- function(n) ifelse(!is.na(n) & n > 0 & n < MIN_CELL, "<10", as.character(n))

fmt_share <- function(n, N) {
  ifelse(n > 0 & n < MIN_CELL, sprintf("<%.3f", MIN_CELL / N), sprintf("%.3f", n / N))
}

fmt_num <- function(x, d) {
  s <- formatC(x, format = "f", digits = d)
  sub("^-(0(\\.0*)?)$", "\\1", s)          # no "-0.00"
}

## NA share as text (count < 10 suppressed)
na_share <- function(x) {
  n <- sum(is.na(x)); N <- length(x)
  if (n == 0) "0" else if (n < MIN_CELL) sprintf("<%.3f (<10)", MIN_CELL / N) else sprintf("%.3f", n / N)
}

## smallest number of decimals (0..max_d) that represents x exactly
natural_digits <- function(x, max_d = 2) {
  for (d in 0:max_d) if (all(abs(x - round(x, d)) < 1e-7)) return(list(d = d, exact = TRUE))
  list(d = max_d, exact = FALSE)
}

## the grid the values lie on (e.g. means of k items = multiples of 1/k)
value_grid <- function(x, dg) {
  if (dg$exact && dg$d == 0) return("integers")
  if (length(unique(x)) >= 3) {
    tol <- if (dg$exact) 0.5 * 10^-dg$d else 1e-6
    for (k in 2:60) {
      if (dg$exact && k %% 10^dg$d == 0) next      # trivially satisfied
      if (all(abs(x * k - round(x * k)) <= tol * k + 1e-7)) {
        return(sprintf("multiples of 1/%d (%s)", k,
                       if (dg$exact) sprintf("stored rounded to %d decimals", dg$d)
                       else "stored at full precision"))
      }
    }
  }
  if (dg$exact) sprintf("multiples of %s", format(10^-dg$d)) else "continuous"
}

## 21 quantiles. Minimum/maximum are exact only when shared by >= MIN_CELL
## participants; otherwise they are bottom-/top-coded at the MIN_CELL-th
## smallest/largest value (so >= MIN_CELL participants lie at or beyond the
## value shown), but never inside the q05..q95 range.
num_summary <- function(x, scale = NULL) {
  x <- sort(as.numeric(x[!is.na(x)]))
  n <- length(x)
  if (n < 2 * MIN_CELL) stop("fewer than ", 2 * MIN_CELL, " values: no marginal written")
  dg <- natural_digits(x)
  q  <- round(quantile(x, PROBS, names = FALSE, type = 7), dg$d)
  q0_coded   <- sum(x <= x[1] + 1e-9) < MIN_CELL
  q100_coded <- sum(x >= x[n] - 1e-9) < MIN_CELL
  if (q0_coded)   q[1]  <- min(round(x[MIN_CELL], dg$d), q[2])
  if (q100_coded) q[21] <- max(round(x[n - MIN_CELL + 1], dg$d), q[20])
  scale_ok <- !is.null(scale) && x[1] >= scale[1] && x[n] <= scale[2]
  n_distinct <- length(unique(x))
  list(
    n = n, digits = dg$d, grid = value_grid(x, dg), n_distinct = n_distinct,
    scale = if (scale_ok) scale else NULL,
    quantiles = setNames(q, sprintf("q%02d", round(PROBS * 100))),
    q0_coded = q0_coded, q100_coded = q100_coded,
    values = if (n_distinct <= 15 && dg$exact) ordinal_table(x, dg$d) else NULL
  )
}

## value shares of a discrete numeric variable; values with < MIN_CELL
## participants are merged with their smaller neighbour (a range; open-ended
## at the lowest/highest value so that the extreme value is not shown)
ordinal_table <- function(x, d = 0) {
  tab <- table(x)
  v <- as.numeric(names(tab)); n <- as.integer(tab)
  grp <- as.list(v)
  while (length(n) > 1 && any(n < MIN_CELL)) {
    i  <- which.min(n)
    nb <- c(i - 1, i + 1); nb <- nb[nb >= 1 & nb <= length(n)]
    j  <- nb[which.min(n[nb])]
    lo <- min(i, j); hi <- max(i, j)
    grp[[lo]] <- c(grp[[lo]], grp[[hi]]); n[lo] <- n[lo] + n[hi]
    grp[[hi]] <- NULL; n <- n[-hi]
  }
  N <- length(x)
  lo_v <- min(v); hi_v <- max(v)
  label <- function(g) {
    if (length(g) == 1) return(fmt_num(g, d))
    if (min(g) == lo_v && max(g) == hi_v) return("all")
    if (min(g) == lo_v) return(paste0("<=", fmt_num(max(g), d)))
    if (max(g) == hi_v) return(paste0(">=", fmt_num(min(g), d)))
    paste0(fmt_num(min(g), d), " to ", fmt_num(max(g), d))
  }
  data.frame(
    value = vapply(grp, label, ""),
    n = if (length(n) == 1 && n < MIN_CELL) "<10" else as.character(n),
    share = sprintf("%.3f", n / N),
    stringsAsFactors = FALSE
  )
}

## level shares of a categorical variable; levels with < MIN_CELL
## participants are pooled into "other" (topped up with the next-smallest
## level until "other" has >= MIN_CELL); for two levels the small one is
## shown as "<10". Returns the display table and the level -> group map
## (the map stays internal: it names rare levels).
cat_table <- function(x, labels = NULL) {
  x <- as.character(x)
  x <- x[!is.na(x)]
  N <- length(x)
  tab <- sort(table(x), decreasing = TRUE)
  lev <- names(tab); n <- as.integer(tab)
  small <- n < MIN_CELL
  group <- setNames(lev, lev)
  pooled <- character(0)
  if (any(small) && length(lev) >= 3) {
    pooled <- lev[small]
    while (sum(n[lev %in% pooled]) < MIN_CELL && length(pooled) < length(lev) - 1) {
      pooled <- c(pooled, rev(setdiff(lev, pooled))[1])
    }
    group[pooled] <- "other"
  }
  keep <- setdiff(lev, pooled)
  rows <- data.frame(level = keep, n_num = n[match(keep, lev)], stringsAsFactors = FALSE)
  if (length(pooled)) {
    rows <- rbind(rows, data.frame(level = "other", n_num = sum(n[lev %in% pooled])))
  }
  rows$label <- if (is.null(labels)) "" else {
    lab <- names(labels)[match(rows$level, as.character(unname(labels)))]
    ifelse(is.na(lab), "", lab)
  }
  rows$label[rows$level == "other"] <- sprintf("%d level(s) with <10 each, pooled", length(pooled))
  ## protection: any shown count < MIN_CELL also hides its complement
  sm <- rows$n_num < MIN_CELL
  rows$n     <- as.character(rows$n_num)
  rows$share <- sprintf("%.3f", rows$n_num / N)
  if (any(sm)) {
    rows$n[sm]      <- "<10"
    rows$share[sm]  <- sprintf("<%.3f", MIN_CELL / N)
    rows$n[!sm]     <- paste0(">", rows$n_num[!sm] - MIN_CELL)
    rows$share[!sm] <- sprintf(">%.3f", (rows$n_num[!sm] - MIN_CELL) / N)
  }
  ok <- !sm                           # groups usable as dummies
  list(table = rows[, c("level", "label", "n", "share")],
       share = setNames(ifelse(ok, rows$n_num / N, NA), rows$level),
       group = group, usable = rows$level[ok], N = N)
}


## ===========================================================================
## correlation matrix (normal scores)
## ===========================================================================

normal_scores <- function(x) qnorm((rank(x, ties.method = "average") - 0.5) / length(x))

## numeric variables as they are; factors dummy-coded (reference = most
## frequent level, pooled "other" as one dummy; dummies with < MIN_CELL in a
## class are left out)
correlation_inputs <- function(data, vars) {
  cols <- list(); dummies <- list(); excluded <- character(0)
  for (v in vars) {
    x <- data[[v]]
    if (is.factor(x) || is.character(x)) {
      ct <- cat_table(x)
      usable <- ct$usable
      if (length(usable) < 2) {
        excluded <- c(excluded, sprintf("%s (all dummies have <10 in one class)", v))
        next
      }
      ref <- usable[1]
      g <- unname(ct$group[as.character(x)])
      for (lv in usable[-1]) {
        nm <- paste0(v, "=", lv)
        cols[[nm]] <- as.numeric(g == lv)
        dummies[[nm]] <- data.frame(dummy = nm, variable = v, level = lv, reference = ref)
      }
      n_unusable <- length(setdiff(names(ct$share), usable))
      if (n_unusable) excluded <- c(excluded, sprintf("%s: %d level(s) with <10 (no dummy)", v, n_unusable))
    } else {
      x <- as.numeric(x)
      if (length(unique(x[!is.na(x)])) < 2) { excluded <- c(excluded, paste(v, "(constant)")); next }
      cols[[v]] <- x
    }
  }
  list(M = as.data.frame(cols, check.names = FALSE),
       dummies = do.call(rbind, dummies), excluded = excluded)
}

## pairwise: normal scores are computed within the rows where both are observed
ns_cor <- function(M) {
  p <- ncol(M); R <- diag(p); dimnames(R) <- list(names(M), names(M))
  complete <- all(complete.cases(M))
  if (complete) {
    S <- vapply(M, normal_scores, numeric(nrow(M)))
    R <- cor(S); dimnames(R) <- list(names(M), names(M))
    return(R)
  }
  for (i in seq_len(p - 1)) for (j in (i + 1):p) {
    ok <- !is.na(M[[i]]) & !is.na(M[[j]])
    R[i, j] <- R[j, i] <- cor(normal_scores(M[[i]][ok]), normal_scores(M[[j]][ok]))
  }
  R
}

## round to 2 decimals, then make positive definite (nearPD) and keep the
## result positive definite after rounding again (shrinking towards the
## identity in 1% steps if necessary)
round_pd <- function(R, tol = 1e-4) {
  min_eig <- function(A) min(eigen(A, symmetric = TRUE, only.values = TRUE)$values)
  R0 <- round(R, 2)
  out <- R0; method <- "rounded (already positive definite)"
  if (min_eig(R0) <= tol) {
    R1 <- as.matrix(nearPD(R0, corr = TRUE, keepDiag = TRUE, eig.tol = 1e-6, posd.tol = 1e-3)$mat)
    shrink <- 1
    repeat {
      out <- round(R1 * shrink, 2); diag(out) <- 1
      if (min_eig(out) > tol || shrink < 0.5) break
      shrink <- shrink - 0.01
    }
    method <- sprintf("Matrix::nearPD after rounding, rounded again%s",
                      if (shrink < 1) sprintf(", off-diagonals shrunk by %.0f%%", 100 * (1 - shrink)) else "")
  }
  dimnames(out) <- dimnames(R)
  list(matrix = out, method = method, min_eigenvalue = round(min_eig(out), 4),
       max_abs_change = round(max(abs(out - R0)), 2))
}

spec_correlation <- function(data, vars, note) {
  ci <- correlation_inputs(data, vars)
  R  <- ns_cor(ci$M)
  pd <- round_pd(R)
  c(list(variables = colnames(pd$matrix), dummies = ci$dummies, excluded = ci$excluded,
         n = nrow(data), note = note,
         basis = "Pearson correlation of normal scores qnorm((rank - 0.5) / n), ties averaged"),
    pd)
}


## ===========================================================================
## raw-column formats
## ===========================================================================

## counts of the string formats found in one raw column (read as character)
raw_format <- function(x) {
  x <- as.character(x)
  pats <- c(
    blank_space  = "^ +$",
    empty        = "^$",
    integer      = "^-?[0-9]+$",
    dec_comma    = "^-?[0-9]+,[0-9]+$",
    dec_comma_no_leading_zero = "^-?,[0-9]+$",
    dec_comma_scientific = "^-?[0-9]*,[0-9]+E[-+]?[0-9]+$",
    dec_point    = "^-?[0-9]*[.][0-9]+$"
  )
  hit <- vapply(pats, function(p) !is.na(x) & grepl(p, x, useBytes = TRUE), logical(length(x)))
  if (is.null(dim(hit))) hit <- matrix(hit, nrow = 1, dimnames = list(NULL, names(pats)))
  cnt <- c(NA_value = sum(is.na(x)), colSums(hit), other = sum(!is.na(x) & rowSums(hit) == 0))
  cnt <- cnt[cnt > 0]
  dec <- x[!is.na(x) & grepl("^-?[0-9]*[,.][0-9]+$", x, useBytes = TRUE)]
  ndec <- nchar(sub("^-?[0-9]*[,.]", "", dec))
  list(
    formats  = paste(sprintf("%s: %s", names(cnt), show_n(cnt)), collapse = "; "),
    decimals = if (length(ndec)) sprintf("%d to %d decimals", min(ndec), max(ndec)) else ""
  )
}

## number of digits of integer strings (for columns whose scale varies)
digit_counts <- function(x) {
  x <- as.character(x)
  x <- x[!is.na(x) & grepl("^-?[0-9]+$", x)]
  if (!length(x)) return("")
  tab <- table(nchar(sub("^-", "", x)))
  if (length(tab) < 2) return("")
  paste(sprintf("%s digits: %s", names(tab), show_n(as.integer(tab))), collapse = "; ")
}

file_info <- function(path, encoding) {
  bytes <- readBin(path, "raw", n = min(file.size(path), 2e6))
  crlf  <- any(bytes[-1] == as.raw(10) & bytes[-length(bytes)] == as.raw(13))
  lines <- readLines(path, warn = FALSE, encoding = "bytes")
  list(
    size_bytes   = file.size(path),
    encoding     = encoding,
    valid_utf8   = all(validUTF8(lines)),
    line_ending  = if (crlf) "CRLF" else "LF",
    physical_lines = length(lines),
    lines_with_double_quote = show_n(sum(grepl("\"", lines, useBytes = TRUE))),
    lines_with_hash = show_n(sum(grepl("#", lines, useBytes = TRUE)))
  )
}


## ===========================================================================
## text lengths
## ===========================================================================

text_summary <- function(texts, language, groups) {
  out <- list()
  for (g in groups) {
    txt <- texts[[g]]
    for (lang in c("all", sort(unique(as.character(language))))) {
      sel <- if (lang == "all") rep(TRUE, length(txt)) else as.character(language) == lang
      t <- txt[sel]
      nonempty <- !is.na(t) & t != ""
      len <- nchar(t[nonempty], type = "chars")
      s <- num_summary(len)
      out[[paste(g, lang)]] <- list(
        response = g, language = lang, n = sum(sel),
        share_of_responses = sprintf("%.3f", sum(sel) / length(txt)),
        n_empty = show_n(sum(!nonempty)),
        share_with_newline = fmt_share(sum(grepl("[\r\n]", t[nonempty])), sum(nonempty)),
        share_non_ascii    = fmt_share(sum(grepl("[^ -~\r\n\t]", t[nonempty])), sum(nonempty)),
        nchar = s
      )
    }
  }
  out
}


## ===========================================================================
## markdown
## ===========================================================================

md_escape <- function(x) gsub("|", "\\|", as.character(x), fixed = TRUE)

md_table <- function(df) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  df[] <- lapply(df, function(c) { c <- as.character(c); c[is.na(c)] <- ""; md_escape(c) })
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")),
    "")
}

md_header <- function(dataset, title) {
  c(sprintf("# Synthetic-data specification: %s", dataset), "",
    sprintf("*%s*", title), "",
    "> **Aggregate statistics only.** Extracted from the real (private) data by",
    "> `synthetic/extract_spec.R` as input for a synthetic-data generator",
    "> (Gaussian copula). It contains no row-level data, no free text and no exact",
    "> individual values:",
    ">",
    "> * counts of 1-9 participants are shown as `<10`; categorical levels with",
    ">   < 10 participants are pooled into `other` (topped up with the next-smallest",
    ">   level until `other` has >= 10); values of ordinal variables are merged with",
    ">   a neighbouring value; a count shown as `<10` also hides its complement (`>N`)",
    "> * minimum and maximum (q00/q100) are exact only if >= 10 participants share",
    ">   that value; otherwise they are bottom-/top-coded at the 10th smallest/largest",
    ">   value (marked `*`: >= 10 participants lie at or beyond it); merged ordinal",
    ">   cells at the ends are open-ended (`<=2`, `>=3`)",
    "> * dummies with < 10 participants in one class are not in the correlation matrix",
    "> * exception: sample-flow numbers (most of them reported in the manuscript)",
    "",
    sprintf("Created %s from embeddings `%s` (only used to rebuild the analysis samples).", Sys.Date(), EMB),
    "")
}

md_flow <- function(flow) {
  c("## 1. Sample flow", "",
    md_table(data.frame(step = names(flow), n = unlist(lapply(flow, function(f) paste(f, collapse = "; "))))))
}

md_numeric <- function(num, info) {
  out <- c("## 3. Numeric marginals (analysed sample)", "",
           "Quantiles q00..q100 (type 7) in the analysed sample, rounded to the variable's",
           "precision. `*` = bottom-/top-coded extreme (the 10th smallest/largest value;",
           "the true minimum/maximum lies beyond it). `scale` = theoretical range of the",
           "instrument or of the value labels, where known. NA share is in the sample",
           "before the complete-case restriction (`NA base`).", "")
  meta <- do.call(rbind, lapply(names(num), function(v) {
    s <- num[[v]]
    data.frame(variable = v, source = info$source[[v]] %||% v, role = info$role[[v]] %||% "",
               n = s$n, `NA base` = s$na_share, decimals = s$digits, grid = s$grid,
               distinct = s$n_distinct,
               scale = if (is.null(s$scale)) "" else paste(s$scale, collapse = " to "),
               check.names = FALSE, stringsAsFactors = FALSE)
  }))
  qt <- do.call(rbind, lapply(names(num), function(v) {
    s <- num[[v]]; q <- fmt_num(s$quantiles, s$digits)
    if (s$q0_coded)   q[1]  <- paste0(q[1], "*")
    if (s$q100_coded) q[21] <- paste0(q[21], "*")
    as.data.frame(as.list(c(variable = v, setNames(q, names(s$quantiles)))), stringsAsFactors = FALSE)
  }))
  out <- c(out, "### Variable information", "", md_table(meta), "### Quantiles", "", md_table(qt))
  vt <- Filter(function(s) !is.null(s$values), num)
  if (length(vt)) {
    out <- c(out, "### Value shares of discrete variables (<= 15 distinct values)", "",
             md_table(data.frame(variable = names(vt), values = vapply(vt, function(s)
               paste(sprintf("%s: %s", s$values$value, s$values$share), collapse = "; "), ""))))
  }
  out
}

md_categorical <- function(cats, info) {
  out <- c("## 4. Categorical variables (analysed sample)", "")
  for (v in names(cats)) {
    out <- c(out, sprintf("**%s** (source `%s`; NA base: %s; N = %d)", v,
                          info$source[[v]] %||% v, cats[[v]]$na_share, cats[[v]]$N), "",
             md_table(cats[[v]]$table))
  }
  out
}

md_correlation <- function(cr) {
  R <- cr$matrix; p <- ncol(R)
  legend <- data.frame(`#` = seq_len(p), variable = colnames(R), check.names = FALSE)
  mat <- matrix(formatC(R, format = "f", digits = 2), nrow = p)
  mat[upper.tri(mat)] <- ""
  w <- 6
  header <- paste0(formatC("", width = 4), paste(formatC(seq_len(p), width = w), collapse = ""))
  rows <- vapply(seq_len(p), function(i)
    paste0(formatC(i, width = 3), " ", paste(formatC(mat[i, ], width = w), collapse = "")), "")
  dummies <- if (is.null(cr$dummies)) data.frame() else cr$dummies
  c("## 5. Correlation matrix", "",
    sprintf("%s. N = %d. %s.", cr$basis, cr$n, cr$note),
    sprintf("Positive definiteness: %s; minimum eigenvalue %.4f; largest change from the rounded matrix %.2f.",
            cr$method, cr$min_eigenvalue, cr$max_abs_change), "",
    "Variables (dummies: `variable=level`, 1 = level, 0 = any other level):", "",
    md_table(legend),
    if (nrow(dummies)) c("Dummy reference levels (most frequent level):", "",
                         md_table(unique(dummies[, c("variable", "reference")]))),
    if (length(cr$excluded)) c("Left out of the matrix:", "", paste("*", cr$excluded), ""),
    "Lower triangle:", "", "```", header, rows, "```", "")
}

md_text <- function(tx, extra = NULL) {
  tab <- do.call(rbind, lapply(tx, function(t) {
    q <- fmt_num(t$nchar$quantiles, 0)
    if (t$nchar$q0_coded)   q[1]  <- paste0(q[1], "*")
    if (t$nchar$q100_coded) q[21] <- paste0(q[21], "*")
    data.frame(response = t$response, language = t$language, n = t$n,
               share = t$share_of_responses, empty = t$n_empty,
               newline = t$share_with_newline, non_ascii = t$share_non_ascii,
               q00 = q[1], q05 = q[2], q10 = q[3], q25 = q[6], q50 = q[11],
               q75 = q[16], q90 = q[19], q95 = q[20], q100 = q[21],
               stringsAsFactors = FALSE)
  }))
  c("## 6. Free-text responses", "",
    "Length in characters of the displayed text (embedded text without the `passage: ` prefix),",
    "non-empty responses only. `share` = share of the responses in this language;",
    "`newline`/`non_ascii` = share of non-empty responses containing a line break / a",
    "non-ASCII character. All 21 quantiles are in the .rds; `*` = bottom-/top-coded extreme.", "",
    md_table(tab), extra)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

zv <- function(x) if (length(x)) paste(x, collapse = ", ") else "none"

write_spec <- function(spec, md) {
  saveRDS(spec, file.path(OUT_DIR, paste0(spec$dataset, ".rds")))
  con <- file(file.path(OUT_DIR, paste0(spec$dataset, ".md")), "w", encoding = "UTF-8")
  writeLines(md, con)
  close(con)
  message("written: ", spec$dataset)
}

## numeric + categorical summaries of one analysed sample
describe_sample <- function(smp_data, vars, base_data, source, scales = list(), labels = list()) {
  num <- list(); cats <- list()
  for (v in vars) {
    x <- smp_data[[v]]
    base_x <- base_data[[source[[v]] %||% v]]
    if (is.factor(x) || is.character(x)) {
      ct <- cat_table(x, labels[[v]])
      cats[[v]] <- list(table = ct$table, N = ct$N, na_share = na_share(base_x))
    } else {
      s <- num_summary(x, scales[[v]])
      s$na_share <- if (any(is.na(x))) na_share(x) else na_share(base_x)
      num[[v]] <- s
    }
  }
  list(numeric = num, categorical = cats)
}


## ===========================================================================
## APEQ
## ===========================================================================

spec_apeq <- function() {
  raw  <- read_apeq_raw()
  prep <- prepare_dataset(EMB, "APEQ")
  smp_who <- prep$make_sample("WHOdiff")
  smp_aaq <- prep$make_sample("AAQdiff")
  same <- identical(smp_who$data$text_text, smp_aaq$data$text_text)
  smp <- smp_who

  raw_text <- clean_apeq_text(raw$SelectedImpactFreeNennung1)
  has_text <- !is.na(raw_text) & raw_text != ""
  excl     <- as.numeric(raw$Exclusion) != 0

  flow <- list(
    raw = nrow(raw),
    raw_by_language = sprintf("%s: %s", names(language_table(raw$Sprache)), show_n(language_table(raw$Sprache))),
    raw_exclusion_code = sprintf("%s: %s", names(table(raw$Exclusion)), show_n(as.integer(table(raw$Exclusion)))),
    after_exclusion = prep$flow$after_exclusion,
    after_exclusion_by_language = sprintf("%s: %d", names(prep$flow$after_exclusion_language), prep$flow$after_exclusion_language),
    with_text = prep$flow$with_text,
    with_text_by_language = sprintf("%s: %d", names(prep$flow$with_text_language), prep$flow$with_text_language),
    raw_with_text_incl_excluded = sum(has_text),
    excluded_with_text_by_language = sprintf("%s: %s", names(table(raw$Sprache[excl & has_text])),
                                             show_n(as.integer(table(raw$Sprache[excl & has_text])))),
    analysed_WHO = smp_who$flow$analysed,
    analysed_AAQ = smp_aaq$flow$analysed,
    analysed_by_language = sprintf("%s: %s", names(smp$flow$analysed_language), show_n(smp$flow$analysed_language)),
    WHO_and_AAQ_samples_identical = same,
    dropped_zero_variance = zv(smp$dropped_zero_variance)
  )

  ## raw columns read by the pipeline
  comma_vars <- c("Dose", "Strength", "Duration", "Valence", "retrospectiveappraisal", "Mood",
                  "Preparedness", "Factor1_Therapeutic", "Factor2_Escapist", "Factor3_Hedonic",
                  "EBI_Total", "CEQ_Total")
  num_vars <- c("WHOdiff", "AAQdiff", "Age...Jahre", "APEQ_AVPE", "APEQ_ACPE")
  role <- c(Exclusion = "filter (0 = included)", Sprache = "language (predictor)",
            setNames(rep("predictor", length(comma_vars)), comma_vars),
            WHOdiff = "outcome", AAQdiff = "outcome", `Age...Jahre` = "predictor",
            APEQ_AVPE = "predictor", APEQ_ACPE = "predictor",
            Gender = "predictor", PsychedelicUsed = "predictor", Education = "predictor (as Education3)",
            SelectedImpactFreeNennung1 = "free text")
  conversion <- c(Exclusion = "as.numeric(x) == 0", Sprache = "as.factor",
                  setNames(rep("as.numeric(gsub(',', '.', x))", length(comma_vars)), comma_vars),
                  setNames(rep("as.numeric(x)", length(num_vars)), num_vars),
                  Gender = "recode 1=Female 2=Male 3=Other -9=NotSpecified",
                  PsychedelicUsed = "recode 1=LSD 2=Psilocybin 3=Mescaline 4=Ayahuasca",
                  Education = "CASMIN 1-3=Primary 4-7=Intermediate 8-9=Higher",
                  SelectedImpactFreeNennung1 = "iconv latin1->UTF-8, squish, drop U+FFFD; empty = no text")
  rc <- do.call(rbind, lapply(names(role), function(v) {
    f <- raw_format(raw[[v]])
    data.frame(column = v, role = role[[v]], class_after_read = class(raw[[v]])[1],
               formats = if (v == "SelectedImpactFreeNennung1")
                 sprintf("blank_space: %s; non-blank text: %s", show_n(sum(grepl("^ *$", raw[[v]], useBytes = TRUE))), sum(has_text))
               else f$formats,
               decimals = f$decimals, conversion = conversion[[v]], stringsAsFactors = FALSE)
  }))
  codes <- lapply(c(Exclusion = "Exclusion", Sprache = "Sprache", Gender = "Gender",
                    PsychedelicUsed = "PsychedelicUsed", Education = "Education"), function(v) {
    x <- raw[[v]]; x[x == " "] <- "' ' (blank = NA)"
    cat_table(x)$table[, c("level", "label", "n", "share")]
  })

  ## analysed sample
  vars <- unique(c("WHOdiff", "AAQdiff", all.vars(reformulate(smp$predictors))))
  smp$data$Education_raw <- smp$data$Education
  prep$data$Education_raw <- prep$data$Education
  desc <- describe_sample(smp$data, c(vars, "Education_raw"), prep$data,
                          source = list(Education3 = "Education3", Education_raw = "Education"))
  desc$categorical$Education_raw$table$label <- ifelse(
    desc$categorical$Education_raw$table$level == "other", desc$categorical$Education_raw$table$label,
    "raw CASMIN code")
  ## raw-file NA shares
  na_raw <- vapply(names(role), function(v) na_share(ifelse(raw[[v]] == " ", NA, raw[[v]])), "")

  cr <- spec_correlation(smp$data, vars,
                         if (same) "Analysed sample (identical for WHO and AAQ)" else "WHO sample")

  texts <- list(text = strip_prefix(prep$data$text_text))
  tx <- text_summary(texts, prep$data$Sprache, "text")

  fi <- file_info(file.path(DATA_RAW, RAW_FILES$APEQ), "latin1")
  notes <- c(
    sprintf("File `%s`: %s columns, separator `;`, header in the first row but read with `header = FALSE` (so every column is character and the column names are the literal header strings, e.g. `Age...Jahre`), `comment.char = \"#\"`.", RAW_FILES$APEQ, ncol(raw)),
    sprintf("Encoding %s (valid UTF-8: %s), line ending %s, %d physical lines for %d data rows; lines containing a double quote: %s; lines containing `#`: %s.",
            fi$encoding, fi$valid_utf8, fi$line_ending, fi$physical_lines, nrow(raw), fi$lines_with_double_quote, fi$lines_with_hash),
    "Missing values in every column are a single space `' '` (as.numeric(' ') gives NA); the text column uses `' '` for no response.",
    "Decimal-comma columns: the factor scores are written without a leading zero (`-,0012`, `,53`), with 11-18 decimals, a few in scientific notation (`1,23E-05`); the other `comma_vars` hold integers in this file.",
    "The generator must not put `#` into the text (comment.char) and must write the file in latin1.",
    "Rows of excluded participants (Exclusion = 1) can be drawn from the same distributions; they are only counted in the flow."
  )

  spec <- list(dataset = "APEQ", created = Sys.Date(), min_cell = MIN_CELL, flow = flow,
               file = fi, notes = notes, raw_columns = cbind(rc, NA_share_raw_file = na_raw),
               raw_codes = codes, numeric = desc$numeric, categorical = desc$categorical,
               correlation = cr, text = tx)
  info <- list(source = list(Education_raw = "Education"),
               role = list(WHOdiff = "outcome", AAQdiff = "outcome"))
  md <- c(md_header("APEQ", "Wolff et al. (2022): APEQ survey (WHO-5 and AAQ change)"),
          md_flow(flow),
          "## 2. Raw columns read by the pipeline", "", paste("*", notes), "",
          md_table(spec$raw_columns),
          "### Codes in the raw file (all rows)", "",
          unlist(lapply(names(codes), function(v) c(sprintf("**%s**", v), "", md_table(codes[[v]])))),
          md_numeric(desc$numeric, info), md_categorical(desc$categorical, info),
          md_correlation(cr), md_text(tx))
  write_spec(spec, md)
}


## ===========================================================================
## GCMQ
## ===========================================================================

spec_gcmq <- function() {
  raw  <- read_gcmq_raw()
  rawc <- read.csv2(file.path(DATA_RAW, RAW_FILES$GCMQ), header = TRUE, comment.char = "#",
                    fileEncoding = "Latin1", colClasses = "character")
  prep <- prepare_dataset(EMB, "GCMQ")
  smp  <- prep$make_sample("WEMWBS")

  src <- c(Language = "LANGUAGE", Age = "IC04_01", Gender = "SD01", Education = "CASMIN",
           Diagnosis = "MH02_07", Depression = "MH02_02", Anxiety = "MH02_01", Adhd = "MH02_08",
           Ptsd = "MH02_09", Addiction = "MH02_04", Mania = "MH02_03", Psychosis = "MH02_05",
           Other_diag = "MH02_06", Substance = "SE01", Clarity = "SE02", Dose = "SE05",
           Valence = "SE10", retrospectiveappraisal = "SE11", conc_none = "SE13_10",
           conc_cannabis = "SE13_02", conc_alcohol = "SE13_01", conc_entact = "SE13_04",
           conc_disso = "SE13_07", conc_stim = "SE13_03", conc_benzo = "SE13_06",
           conc_opiat = "SE13_05", conc_other = "SE13_09", Suitability = "S204")
  vars <- unique(c("WEMWBS", all.vars(reformulate(smp$predictors))))
  identity_vars <- setdiff(c(vars, "GCMQ_RE"), names(src))
  ev_cols <- grep("MH05x|MH06", names(raw), value = TRUE)
  he_cols <- grep("MH04x|MH07", names(raw), value = TRUE)

  nb <- function(x) !is.na(x) & grepl("[^ ]", x)
  ev_any <- Reduce(`|`, lapply(ev_cols, function(v) nb(raw[[v]])))
  he_any <- Reduce(`|`, lapply(he_cols, function(v) nb(raw[[v]])))
  bylang <- function(sel) { t <- table(raw$LANGUAGE[sel]); sprintf("%s: %s", names(t), show_n(as.integer(t))) }

  flow <- list(
    raw = nrow(raw),
    raw_by_language = sprintf("%s: %d", names(prep$flow$raw_language), prep$flow$raw_language),
    with_events_text = sum(ev_any), with_health_text = sum(he_any),
    with_events_text_by_language = bylang(ev_any), with_health_text_by_language = bylang(he_any),
    with_both_texts = prep$flow$with_text,
    with_both_texts_by_language = sprintf("%s: %d", names(prep$flow$with_text_language), prep$flow$with_text_language),
    analysed_WEMWBS = smp$flow$analysed,
    analysed_by_language = sprintf("%s: %s", names(smp$flow$analysed_language), show_n(smp$flow$analysed_language)),
    dropped_zero_variance = zv(smp$dropped_zero_variance)
  )

  role_of <- function(col) {
    if (col %in% c(ev_cols, he_cols)) return("free text")
    if (col == "LANGUAGE") return("language (predictor)")
    if (col == "WEMWBS") return("outcome")
    if (col == "GCMQ_RE") return("read for a manuscript number only (count of NA)")
    "predictor"
  }
  cols <- c(unname(src), identity_vars, ev_cols, he_cols)
  rc <- do.call(rbind, lapply(cols, function(v) {
    f <- raw_format(rawc[[v]])
    txt <- v %in% c(ev_cols, he_cols)
    data.frame(
      column = v, model_variable = names(src)[match(v, src)] %||% v, role = role_of(v),
      class_after_read = class(raw[[v]])[1],
      formats = if (txt) sprintf("blank_space: %s; non-blank: %s; with `<br>`: %s",
                                 show_n(sum(grepl("^ *$", rawc[[v]]))), show_n(sum(nb(rawc[[v]]))),
                                 show_n(sum(grepl("<br>", rawc[[v]], fixed = TRUE))))
                else f$formats,
      decimals = f$decimals, digit_counts = if (txt) "" else digit_counts(rawc[[v]]),
      NA_share_raw_file = na_share(ifelse(grepl("^ *$", rawc[[v]]), NA, rawc[[v]])),
      stringsAsFactors = FALSE)
  }))
  rc$model_variable[is.na(rc$model_variable)] <- rc$column[is.na(rc$model_variable)]
  rc$model_variable[rc$role == "free text"] <- ifelse(rc$column[rc$role == "free text"] %in% ev_cols,
                                                      "text_events", "text_health")

  ## which text columns are filled, among participants with both texts
  keep <- gcmq_text_frame(raw)$keep
  pattern <- function(cols_) apply(vapply(cols_, function(v) nb(raw[[v]][keep]), logical(sum(keep))), 1,
                                   function(r) if (any(r)) paste(cols_[r], collapse = "+") else "(none)")
  patterns <- list(events = cat_table(pattern(ev_cols))$table, health = cat_table(pattern(he_cols))$table)

  base <- prep$data
  desc <- describe_sample(smp$data, vars, base, source = list(), scales = list(WEMWBS = c(14, 70)))
  info <- list(source = as.list(src), role = list(WEMWBS = "outcome"))

  cr <- spec_correlation(smp$data, vars, "Analysed WEMWBS sample")
  texts <- list(events = strip_prefix(prep$data$text_events), health = strip_prefix(prep$data$text_health))
  tx <- text_summary(texts, prep$data$Language, c("events", "health"))

  fi <- file_info(file.path(DATA_RAW, RAW_FILES$GCMQ), "latin1")
  notes <- c(
    sprintf("File `%s`: %d columns, read with `read.csv2(header = TRUE, comment.char = \"#\", fileEncoding = \"Latin1\")`; numeric columns are converted by read.csv2 (decimal comma).", RAW_FILES$GCMQ, ncol(raw)),
    sprintf("Encoding %s (valid UTF-8: %s), line ending %s, %d physical lines for %d data rows; lines containing a double quote: %s; lines containing `#`: %s.",
            fi$encoding, fi$valid_utf8, fi$line_ending, fi$physical_lines, nrow(raw), fi$lines_with_double_quote, fi$lines_with_hash),
    "Missing values / no response are a single space `' '` (blank fields become NA in numeric columns).",
    "Text: `events` = all columns matching `MH05x|MH06` pasted with spaces, `health` = columns matching `MH04x|MH07`; no other column may match these patterns. MH05x*/MH04x* are the item names before a questionnaire change (short multi-field answers), MH06_01/MH07_01 after it. `<br>` in the text is replaced by a space.",
    "Int_Ther/Int_Hedo/Int_Esca are decimal-comma factor scores without a leading zero (`-,0017`), a few in scientific notation (`1,23E-05`); APEQ_AVE, APEQ_ACE, ASC_OBE and EBI are stored as integers whose number of digits varies (see `digit_counts`; they look like means with the decimal separator lost), reproduced as stored.",
    sprintf("Responses that consist only of `<br>` pass the non-empty filter but are empty after the replacement (embedded as the bare prefix): events %s, health %s.",
            show_n(sum(texts$events == "")), show_n(sum(texts$health == ""))),
    "The generator must not put `#` into the text (comment.char)."
  )
  spec <- list(dataset = "GCMQ", created = Sys.Date(), min_cell = MIN_CELL, flow = flow, file = fi,
               notes = notes, raw_columns = rc, text_column_patterns = patterns,
               numeric = desc$numeric, categorical = desc$categorical, correlation = cr, text = tx)
  md <- c(md_header("GCMQ", "Wolff et al. (2024): GCMQ survey (WEMWBS)"),
          md_flow(flow),
          "## 2. Raw columns read by the pipeline", "", paste("*", notes), "",
          md_table(rc),
          "### Filled text columns among participants with both texts", "",
          "**events**", "", md_table(patterns$events), "**health**", "", md_table(patterns$health),
          md_numeric(desc$numeric, info), md_categorical(desc$categorical, info),
          md_correlation(cr), md_text(tx))
  write_spec(spec, md)
}


## ===========================================================================
## PTSD
## ===========================================================================

spec_ptsd <- function() {
  raw  <- read_ptsd_raw()
  raw0 <- read_sav(file.path(DATA_RAW, RAW_FILES$PTSD), encoding = "windows-1252")   # labels unrepaired
  prep <- prepare_dataset(EMB, "PTSD")
  smp_pcl  <- prep$make_sample("pcl_sum")
  smp_ptgi <- prep$make_sample("ptgi_sum")

  subs_cols <- grep("^subs_", names(raw), value = TRUE)
  src <- c(Language = "LANGUAGE", Gender = "gender", Age = "age", Country = "country", Edu = "edu",
           valence = "acute_exp", challenge = "challenge_exp", motive_hedonic = "FAC1_1",
           motive_selfexploration = "FAC2_1", motive_escapist = "FAC3_1")
  preds <- unlist(prep$predictor_blocks, use.names = FALSE)
  pred_src <- ifelse(preds %in% names(src), src[preds], preds)

  ## flow: who is excluded, and why
  groups <- prep$groups
  text_missing <- Reduce(`|`, lapply(groups, function(g) is.na(prep$data[[paste0(g, "_E0001")]])))
  pred_missing <- Reduce(`|`, lapply(pred_src, function(v) is.na(raw[[v]])))
  excl <- function(outcome, smp) {
    has <- !is.na(raw[[outcome]])
    list(with_outcome = sum(has), analysed = smp$flow$analysed,
         excluded_empty_text_only = sum(has & text_missing & !pred_missing),
         excluded_missing_predictor_only = sum(has & pred_missing & !text_missing),
         excluded_both = sum(has & pred_missing & text_missing))
  }
  e_pcl <- excl("pcl_sum", smp_pcl); e_ptgi <- excl("ptgi_sum", smp_ptgi)
  stopifnot(e_pcl$with_outcome - e_pcl$analysed ==
              e_pcl$excluded_empty_text_only + e_pcl$excluded_missing_predictor_only + e_pcl$excluded_both)
  miss_vars <- pred_src[vapply(pred_src, function(v) any(is.na(raw[[v]])), TRUE)]
  flow <- list(
    raw = nrow(raw),
    raw_by_language = sprintf("%s: %d", names(prep$flow$raw_language), prep$flow$raw_language),
    empty_text_acute = prep$flow$empty_acute, empty_text_post = prep$flow$empty_post,
    empty_text_treat = prep$flow$empty_treat,
    empty_text_any = sum(text_missing),
    participants_lacking_a_nontext_predictor = sum(pred_missing),
    predictors_with_missing_values = if (length(miss_vars)) paste(sprintf("%s (%s)", miss_vars,
      show_n(vapply(miss_vars, function(v) sum(is.na(raw[[v]])), 1L))), collapse = ", ") else "none",
    PCL_with_outcome = e_pcl$with_outcome, PCL_analysed = e_pcl$analysed,
    PCL_excluded_empty_text_only = e_pcl$excluded_empty_text_only,
    PCL_excluded_missing_predictor_only = e_pcl$excluded_missing_predictor_only,
    PCL_excluded_both = e_pcl$excluded_both,
    PCL_analysed_by_language = sprintf("%s: %s", names(smp_pcl$flow$analysed_language), show_n(smp_pcl$flow$analysed_language)),
    PCL_dropped_zero_variance = zv(smp_pcl$dropped_zero_variance),
    PTGI_with_outcome = e_ptgi$with_outcome, PTGI_analysed = e_ptgi$analysed,
    PTGI_excluded_empty_text_only = e_ptgi$excluded_empty_text_only,
    PTGI_excluded_missing_predictor_only = e_ptgi$excluded_missing_predictor_only,
    PTGI_excluded_both = e_ptgi$excluded_both,
    PTGI_analysed_by_language = sprintf("%s: %s", names(smp_ptgi$flow$analysed_language), show_n(smp_ptgi$flow$analysed_language)),
    PTGI_dropped_zero_variance = zv(smp_ptgi$dropped_zero_variance)
  )

  ## raw columns (SPSS attributes)
  text_cols <- unname(PTSD_TEXT_VARS)
  cols <- unique(c("LANGUAGE", "gender", "age", "country", "edu", subs_cols, "dose_exp", "clear_exp",
                   "duration_exp", "acute_exp", "evaluation_exp", "challenge_exp", "FAC1_1", "FAC2_1",
                   "FAC3_1", "ceq_mean", "apeq_ACE_mean", "apeq_AVE_mean", "pcl_sum", "ptgi_sum", text_cols))
  is_text <- function(v) is.character(raw[[v]]) && v != "LANGUAGE"
  rc <- do.call(rbind, lapply(cols, function(v) {
    x <- raw[[v]]
    labs <- attr(x, "labels")
    data.frame(
      column = v,
      model_variable = names(src)[match(v, src)] %||% v,
      class = paste(class(x), collapse = "/"), type = typeof(x),
      format.spss = attr(x, "format.spss") %||% "",
      display_width = as.character(attr(x, "display_width") %||% ""),
      variable_label = paste(attr(x, "label") %||% "", collapse = " / "),
      n_value_labels = length(labs),
      NA_count = show_n(sum(is.na(x))),
      empty_strings = if (is.character(x)) show_n(sum(x == "", na.rm = TRUE)) else "",
      non_empty_text = if (is_text(v)) show_n(sum(!is.na(x) & x != "")) else "",
      stringsAsFactors = FALSE)
  }))
  rc$model_variable[is.na(rc$model_variable)] <- rc$column[is.na(rc$model_variable)]
  rc$model_variable[rc$column %in% c("subs_other_text", "subs_DOM", "subs_DOI")] <- "(not used)"
  value_labels <- lapply(setNames(cols, cols), function(v) attr(raw[[v]], "labels"))
  value_labels <- Filter(Negate(is.null), value_labels)
  ## how many labels were stored as mojibake (repaired by repair_labels())
  n_var_lab_fixed <- sum(vapply(cols, function(v) !identical(attr(raw0[[v]], "label"), attr(raw[[v]], "label")), TRUE))
  n_val_lab_fixed <- sum(vapply(cols, function(v) sum(names(attr(raw0[[v]], "labels")) != names(attr(raw[[v]], "labels"))), 1L))

  ## analysed sample (PCL) + ptgi where available
  d <- smp_pcl$data
  vars <- unique(c("pcl_sum", "ptgi_sum", all.vars(reformulate(smp_pcl$predictors))))
  d$country_raw <- as.character(as.numeric(d$country)); d$edu_raw <- as.character(as.numeric(d$edu))
  lab_of <- function(col) attr(raw[[col]], "labels")
  scales <- list(pcl_sum = c(0, 80), ptgi_sum = c(0, 105))
  for (v in c("dose_exp", "clear_exp", "duration_exp", "valence", "evaluation_exp", "challenge")) {
    l <- lab_of(if (v %in% names(src)) src[[v]] else v); l <- l[l >= 0]
    if (length(l)) scales[[v]] <- range(as.numeric(l))
  }
  base <- raw; base$country_raw <- as.numeric(raw$country); base$edu_raw <- as.numeric(raw$edu)
  desc <- describe_sample(d, c(vars, "country_raw", "edu_raw"), base,
                          source = c(as.list(src), country_raw = "country", edu_raw = "edu"),
                          scales = scales,
                          labels = list(Gender = lab_of("gender"), country_raw = lab_of("country"),
                                        edu_raw = lab_of("edu"), Country = lab_of("country"),
                                        Edu = lab_of("edu")))
  desc$numeric$ptgi_sum$na_share <- sprintf("%s in the PCL sample", na_share(d$ptgi_sum))
  info <- list(source = c(as.list(src), country_raw = "country", edu_raw = "edu"),
               role = list(pcl_sum = "outcome", ptgi_sum = "outcome"))

  cr <- spec_correlation(d, vars, sprintf(
    "Analysed PCL sample; correlations with ptgi_sum pairwise over the %d participants of this sample with a PTGI score",
    sum(!is.na(d$ptgi_sum))))

  texts <- lapply(PTSD_TEXT_VARS, function(v) { x <- raw[[v]]; x[is.na(x)] <- ""; trimws(x) })
  tx <- text_summary(texts, raw$LANGUAGE, names(PTSD_TEXT_VARS))

  fi <- list(size_bytes = file.size(file.path(DATA_RAW, RAW_FILES$PTSD)), columns = ncol(raw), rows = nrow(raw))
  notes <- c(
    sprintf("File `%s` (SPSS .sav, %d columns), read with `haven::read_sav(encoding = \"windows-1252\")`, then `repair_labels()` (variable and value labels stored as UTF-8 bytes read as windows-1252); %d variable labels and %d value labels of the columns below are changed by that repair.", RAW_FILES$PTSD, ncol(raw), n_var_lab_fixed, n_val_lab_fixed),
    "The free-text columns are read correctly with windows-1252 (umlauts intact, no mojibake). A generator writing with `haven::write_sav()` (always UTF-8) gets labels that `repair_labels()` repairs, but non-ASCII characters in the text columns would arrive as mojibake: keep synthetic PTSD texts ASCII (e.g. ae/oe/ue/ss) or check the round trip.",
    "Empty responses are empty strings `\"\"` (no NA) in the text columns; `prepare_ptsd()` treats them as missing (PTSD_ALL_EMPTY_TEXTS_MISSING = TRUE).",
    "All columns starting with `subs_` are read; `subs_other_text` (free text, mostly empty), `subs_DOM` and `subs_DOI` (constant 0) are dropped by the pipeline, the others are predictors: names containing `count` as integers, the rest as factors.",
    "Rare countries / education levels (<= 5 participants with the outcome) are pooled by the pipeline into code 999 (`Country`, `Edu`); `country_raw`/`edu_raw` show the raw codes.",
    "Negative codes (e.g. -9 = Not answered) are values, not NA, if they occur."
  )
  vl_md <- unlist(lapply(names(value_labels), function(v) {
    l <- value_labels[[v]]
    if (length(l) > 20) sprintf("* `%s`: %d value labels (full list in the .rds)", v, length(l))
    else sprintf("* `%s`: %s", v, paste(sprintf("%s = %s", unname(l), names(l)), collapse = "; "))
  }))
  spec <- list(dataset = "PTSD", created = Sys.Date(), min_cell = MIN_CELL, flow = flow, file = fi,
               notes = notes, raw_columns = rc, value_labels = value_labels,
               numeric = desc$numeric, categorical = desc$categorical, correlation = cr, text = tx)
  md <- c(md_header("PTSD", "Evens et al. (2026): psychedelic-related PTSD symptoms (PCL-5, PTGI)"),
          md_flow(flow),
          "## 2. Raw columns read by the pipeline", "", paste("*", notes), "",
          md_table(rc), "### Value labels (after repair_labels)", "", vl_md, "",
          md_numeric(desc$numeric, info), md_categorical(desc$categorical, info),
          md_correlation(cr), md_text(tx))
  write_spec(spec, md)
}


## ===========================================================================
## run
## ===========================================================================

spec_apeq()
spec_gcmq()
spec_ptsd()
