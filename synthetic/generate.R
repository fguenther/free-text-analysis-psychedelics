## ---------------------------------------------------------------------------
## generate.R
##
## Generates the SYNTHETIC raw data files (data/raw/synthetic_*.csv/.sav) on
## which this repository runs the pipeline of the study. Seeded: running it
## again gives the same files. run_all.R calls it if the files are missing.
##
## Inputs (all published in this repository):
##   synthetic/texts/*.csv        the synthetic free-text responses, written for
##                                this repository (see synthetic/texts/CODEBOOK.md),
##                                each tagged with theme scores (0-3)
##   synthetic/spec_public/*.rds  aggregate statistics of the original data:
##                                sample sizes, quantiles of every variable,
##                                category shares, a correlation matrix of normal
##                                scores (synthetic/spec_public/*.md: readable)
##
## Per dataset:
##   1. Every analysed participant gets synthetic response(s); the response
##      language is the participant's language.
##   2. Non-text predictors are drawn from a Gaussian copula with the
##      correlation matrix of the original data (conditional on language) and
##      mapped onto the original quantiles / category shares.
##   3. OVERLAP: some predictors are shifted towards theme scores of the
##      participant's response (e.g. therapeutic use motives <-> responses
##      about therapeutic use), so that text and predictors share information.
##   4. The outcomes are drawn from the copula conditional on these predictors
##      (baseline signal), plus the PLANTED text signal: a weighted sum of
##      theme scores of the response(s) (SIGNAL below), then mapped onto the
##      original quantiles.
## The planted signal mirrors the published results: text adds to WHO-5,
## AAQ-II (APEQ) and PCL-5 (PTSD: "post" strongly, "treat" moderately, "acute"
## not at all); it adds nothing to WEMWBS (GCMQ; at most a trace via "health")
## and PTGI (PTSD), which serve as null outcomes.
##
## The raw files reproduce the formats of the original raw files (column
## names, codes, decimal commas, encodings), so R/datasets.R reads them
## unchanged. Only the columns the pipeline uses are included.
## ---------------------------------------------------------------------------

suppressMessages(library(haven))
if (!exists("DATA_RAW")) source("R/config.R")
## never overwrite real data: only with SYNTHETIC = TRUE and synthetic file names
if (!isTRUE(SYNTHETIC) || !all(grepl("^synthetic_", unlist(RAW_FILES)))) {
  stop("generate.R writes synthetic data only: needs SYNTHETIC = TRUE and RAW_FILES ",
       "named synthetic_* (R/config_data.R)")
}

GEN_SEED  <- 20261113
SPEC_DIR  <- "synthetic/spec_public"
TEXT_DIR  <- "synthetic/texts"

## --- planted text signal ----------------------------------------------------------
## Per outcome: one or more text components, each a weighted sum of theme
## scores of one response type, rank-transformed to a standard normal score
## and added to the outcome (on the normal-score scale of the copula, where
## the outcome has variance 1) with weight b.
SIGNAL <- list(
  APEQ = list(
    WHOdiff = list(list(group = "text", b = 0.37,
                        themes = c(pos_affect = 1, insight = -1))),
    AAQdiff = list(list(group = "text", b = 0.25,
                        themes = c(acceptance = -1, pos_affect = -0.5, insight = 0.8)))
  ),
  GCMQ = list(
    WEMWBS = list(list(group = "health", b = 0.08,
                       themes = c(euphoria_love = 1, open_mind = 1, appreciation = 1,
                                  indifference = -1, short_lived = -1, no_impact = -1)))
  ),
  PTSD = list(
    pcl_sum = list(
      list(group = "post", b = 0.35,
           themes = c(anxiety_panic = 1, dpdr = 1, depression = 1, hppd_visual = 1,
                      intrusive = 1, other_symptoms = 1, no_difficulty = -2, self_insight = -1.5)),
      list(group = "treat", b = 0.15,
           themes = c(still_struggling = 1, helped = -1)))
    ## ptgi_sum: no text signal
  )
)

## --- overlap of text and other predictors ---------------------------------------------
## predictor (copula variable) <- sqrt(1 - a^2) * predictor + a * theme score
## (normal scores), applied in this order
OVERLAP <- list(
  APEQ = data.frame(
    group    = "text",
    theme    = c("therapeutic", "pos_affect", "pos_affect", "acceptance",
                 "challenging", "mystical", "acceptance"),
    variable = c("Factor1_Therapeutic", "retrospectiveappraisal", "APEQ_ACPE", "APEQ_ACPE",
                 "CEQ_Total", "EBI_Total", "EBI_Total"),
    a        = c(0.50, 0.45, 0.45, 0.35, 0.30, 0.35, 0.30)),
  GCMQ = data.frame(
    group    = c("health", "health", "events", "events", "health", "health",
                 "health", "events"),
    theme    = c("symptom_relief", "negative", "calm_coping", "self_insight",
                 "euphoria_love", "appreciation", "negative", "perspective"),
    variable = c("Int_Ther", "CEQ", "GCMQ_RA", "GCMQ_CL", "ASC_OBE", "retrospectiveappraisal",
                 "Int_Esca", "GCMQ_MA"),
    a        = c(0.30, 0.25, 0.45, 0.25, 0.35, 0.35, 0.35, 0.35)),
  PTSD = data.frame(
    group    = c("acute", "acute", "acute", "acute", "post", "post"),
    theme    = c("fear_panic", "fear_panic", "loss_control", "resolution",
                 "self_insight", "no_difficulty"),
    variable = c("ceq_mean", "challenge", "apeq_AVE_mean", "apeq_ACE_mean",
                 "evaluation_exp", "evaluation_exp"),
    a        = c(0.35, 0.30, 0.25, 0.25, 0.20, 0.20))
)

## =====================================================================================
## helpers
## =====================================================================================

read_spec <- function(dataset) readRDS(file.path(SPEC_DIR, paste0(dataset, ".rds")))

## all batches of one response type, in file order
read_corpus <- function(stem) {
  files <- sort(list.files(TEXT_DIR, pattern = paste0("^", stem, "_[0-9]+\\.csv$"), full.names = TRUE))
  if (!length(files)) stop("no corpus files for ", stem, " in ", TEXT_DIR)
  d <- do.call(rbind, lapply(files, read.csv, fileEncoding = "UTF-8",
                             colClasses = c(id = "character", language = "character",
                                            text = "character"),
                             na.strings = character()))
  d$text[is.na(d$text)] <- ""
  if (anyDuplicated(d$id)) stop(stem, ": duplicated ids")
  d
}

## a count stored as text -> number: "645" -> 645, ">590" -> 590 (the
## complement of a suppressed cell), "<10" and other suppressed counts -> 5
as_count <- function(x) {
  x <- trimws(as.character(x))
  n <- suppressWarnings(as.numeric(sub("^>", "", x)))
  n[is.na(n) | grepl("^<", x)] <- 5
  n
}

## normal scores of a composite (ties: average rank); NA stays NA
normal_scores <- function(x) {
  out <- rep(NA_real_, length(x))
  ok  <- !is.na(x)
  out[ok] <- qnorm(rank(x[ok]) / (sum(ok) + 1))
  out
}

## normal scores rescaled to mean 0, sd 1 (theme scores have many ties, so
## their normal scores alone would have a variance below 1); NA -> 0 later
std_scores <- function(x) { z <- normal_scores(x); (z - mean(z, na.rm = TRUE)) / sd(z, na.rm = TRUE) }

## theme composite of one text component: weighted sum of theme scores
composite <- function(scores, themes) {
  miss <- setdiff(names(themes), names(scores))
  if (length(miss)) stop("unknown themes: ", paste(miss, collapse = ", "))
  as.vector(as.matrix(scores[, names(themes), drop = FALSE]) %*% themes)
}

## draw from N(0, R) given the values of some columns (rows = participants)
cond_mvn <- function(R, given, z_given) {
  n <- nrow(z_given)
  B <- setdiff(seq_len(ncol(R)), given)
  K <- R[B, given, drop = FALSE] %*% solve(R[given, given, drop = FALSE])
  S <- R[B, B, drop = FALSE] - K %*% R[given, B, drop = FALSE]
  Z <- matrix(NA_real_, n, ncol(R), dimnames = list(NULL, colnames(R)))
  Z[, given] <- z_given
  Z[, B] <- z_given %*% t(K) + matrix(rnorm(n * length(B)), n) %*% chol(S)
  Z
}

## language as a latent normal: "ger" above the threshold, "eng" below
latent_language <- function(lang, p_ger) {
  u <- ifelse(lang == "ger", runif(length(lang), 1 - p_ger, 1), runif(length(lang), 0, 1 - p_ger))
  qnorm(u)
}

## normal score -> value on the original scale (quantiles q05..q95, tails
## extended linearly by one step and clamped to the scale bounds)
qmap <- function(z, s) {
  q <- unname(s$quantiles)
  p <- as.numeric(sub("^q", "", names(s$quantiles))) / 100
  k <- length(q)
  lo <- q[1] - (q[2] - q[1])
  hi <- q[k] + (q[k] - q[k - 1])
  if (!is.null(s$scale)) { lo <- max(lo, s$scale[1]); hi <- min(hi, s$scale[2]) }
  x <- approx(c(0, p, 1), c(min(lo, q[1]), q, max(hi, q[k])), xout = pnorm(z), ties = "ordered")$y
  if (identical(s$grid, "integers") || identical(as.integer(s$digits), 0L)) round(x) else round(x, 6)
}

## categorical variable: dummies present in the copula decide first (largest
## exceedance of its threshold wins); everybody else is distributed over the
## remaining levels by their shares. "other" (pooled rare levels) -> code "other".
draw_categorical <- function(Z, var, tab) {
  lev   <- tab$level
  share <- as_count(tab$n) / sum(as_count(tab$n))
  dummies <- intersect(paste0(var, "=", lev), colnames(Z))
  out <- rep(NA_character_, nrow(Z))
  if (length(dummies)) {
    dl  <- sub("^[^=]*=", "", dummies)
    thr <- qnorm(1 - share[match(dl, lev)])
    exc <- sweep(Z[, dummies, drop = FALSE], 2, thr)
    hit <- apply(exc, 1, function(e) if (any(e > 0)) which.max(e) else NA_integer_)
    out[!is.na(hit)] <- dl[hit[!is.na(hit)]]
    rest_lev <- setdiff(lev, dl)
  } else rest_lev <- lev
  todo <- is.na(out)
  if (any(todo)) {
    if (!length(rest_lev)) rest_lev <- lev
    out[todo] <- sample(rest_lev, sum(todo), replace = TRUE,
                        prob = share[match(rest_lev, lev)])
  }
  out
}

## codes for the pooled "other" level: k unused integer codes, spread evenly
## (each code used by few participants, as rare levels are)
other_codes <- function(tab, n) {
  k <- suppressWarnings(as.integer(sub("^.*?([0-9]+) level.*$", "\\1", tab$label[tab$level == "other"])))
  if (!length(k) || is.na(k)) k <- 2
  used  <- suppressWarnings(as.integer(tab$level))
  codes <- setdiff(seq_len(max(c(used, 0), na.rm = TRUE) + k + 5), used)[seq_len(k)]
  rep_len(sample(codes), n)
}

## values on the original scales: numeric variables from their normal scores
## (independent draws if not in the copula), categories as decided in
## draw_participants (or drawn by their shares if not in the copula)
fill_values <- function(draw, spec, numeric_vars, cat_vars) {
  Z <- draw$Z
  out <- list()
  for (v in numeric_vars) {
    z <- if (v %in% colnames(Z)) Z[, v] else rnorm(nrow(Z))
    out[[v]] <- qmap(z, spec$numeric[[v]])
  }
  for (v in cat_vars) {
    out[[v]] <- if (!is.null(draw$cats[[v]])) draw$cats[[v]] else
      draw_categorical(Z, v, spec$categorical[[v]]$table)
  }
  out
}

## --- text cleaning for the file formats -------------------------------------------------
plain_punct <- function(x) {
  x <- gsub("[“”„«»]", "\"", x)
  x <- gsub("[‘’‚]", "'", x)
  x <- gsub("[–—]", "-", x)
  x <- gsub("…", "...", x)
  x <- gsub("#", "Nr. ", x, fixed = TRUE)            # comment.char of the CSV readers
  x
}
to_latin1_safe <- function(x) {
  x <- plain_punct(x)
  y <- iconv(x, "UTF-8", "latin1", sub = "")
  iconv(y, "latin1", "UTF-8")                         # back to UTF-8 strings
}
to_ascii <- function(x) {
  x <- plain_punct(x)
  map <- c("ä" = "ae", "ö" = "oe", "ü" = "ue", "Ä" = "Ae",
           "Ö" = "Oe", "Ü" = "Ue", "ß" = "ss")
  for (ch in names(map)) x <- gsub(ch, map[[ch]], x, fixed = TRUE)
  x <- chartr("éèêàâçñóôíúáëï",
              "eeeaacnooiuaei", x)
  iconv(x, "UTF-8", "ASCII", sub = "")
}

## --- number formats ------------------------------------------------------------------
fmt_int_raw <- function(x) ifelse(is.na(x), " ", sprintf("%d", as.integer(round(x))))
## decimal comma, no leading zero (",53", "-,0012"), as the factor scores in the originals
fmt_deccomma <- function(x) {
  s <- formatC(x, format = "f", digits = 15)
  s <- sub("^(-?)0\\.", "\\1.", s)
  s <- sub(".", ",", s, fixed = TRUE)
  ifelse(is.na(x), " ", s)
}
csv_quote <- function(x) paste0("\"", gsub("\"", "\"\"", x, fixed = TRUE), "\"")

## semicolon CSV in latin1 with CRLF line endings
write_csv2_latin1 <- function(cells, file) {
  lines <- apply(cells, 1, paste, collapse = ";")
  lines <- iconv(lines, "UTF-8", "latin1")
  if (anyNA(lines)) stop("text not representable in latin1")
  con <- file(file, "wb")
  on.exit(close(con))
  writeLines(lines, con, sep = "\r\n", useBytes = TRUE)
}

## --- the copula part for one set of participants -----------------------------------------
## lang: language per participant; text_scores: named list of theme score data
## frames (one per response type, rows = participants; NULL = no text)
draw_participants <- function(spec, dataset, lang, text_scores = NULL) {
  cr <- spec$correlation
  R  <- cr$matrix
  dimnames(R) <- list(cr$variables, cr$variables)
  lang_var <- grep("^(Sprache|Language)=ger$", cr$variables, value = TRUE)
  outcomes <- intersect(names(spec$numeric), c("WHOdiff", "AAQdiff", "WEMWBS", "pcl_sum", "ptgi_sum"))
  X <- setdiff(cr$variables, outcomes)

  ## 1. predictors, conditional on language
  p_ger <- mean(lang == "ger")
  RX <- R[X, X]
  ZX <- cond_mvn(RX, match(lang_var, X), matrix(latent_language(lang, p_ger)))

  ## 2. overlap with the text themes
  if (!is.null(text_scores)) {
    ov <- OVERLAP[[dataset]]
    for (i in seq_len(nrow(ov))) {
      f <- std_scores(text_scores[[ov$group[i]]][[ov$theme[i]]])
      f[is.na(f)] <- 0
      ZX[, ov$variable[i]] <- sqrt(1 - ov$a[i]^2) * ZX[, ov$variable[i]] + ov$a[i] * f
    }
  }

  ## 3. categories are decided now, and their dummies enter the outcomes as
  ##    the observed (standardised) indicators, not as latent normals, so the
  ##    outcomes depend on what the models can see
  dummy_vars <- unique(sub("=.*", "", grep("=", X, value = TRUE)))
  cats <- list()
  for (v in dummy_vars) {
    lev_v <- if (v %in% c("Sprache", "Language")) lang else
      draw_categorical(ZX, v, spec$categorical[[v]]$table)
    cats[[v]] <- lev_v
    for (dm in grep(paste0("^", v, "="), X, value = TRUE)) {
      ind <- as.numeric(lev_v == sub("^[^=]*=", "", dm))
      ZX[, dm] <- if (sd(ind) > 0) (ind - mean(ind)) / sd(ind) else 0
    }
  }

  ## 4. outcomes given the predictors, plus the planted text signal
  K  <- R[outcomes, X, drop = FALSE] %*% solve(RX)
  SY <- R[outcomes, outcomes, drop = FALSE] - K %*% R[X, outcomes, drop = FALSE]
  ## the overlap step changes how the predictors covary; the predictable part
  ## is rescaled so that it keeps the variance (R^2) it has in the copula
  lin <- ZX %*% t(K)
  r2  <- diag(K %*% R[X, outcomes, drop = FALSE])
  lin <- sweep(lin, 2, sqrt(r2) / apply(lin, 2, sd), "*")
  ZY <- lin + matrix(rnorm(nrow(ZX) * length(outcomes)), nrow(ZX)) %*% chol(SY)
  colnames(ZY) <- outcomes
  if (!is.null(text_scores)) {
    for (y in names(SIGNAL[[dataset]])) {
      for (comp in SIGNAL[[dataset]][[y]]) {
        f <- std_scores(composite(text_scores[[comp$group]], comp$themes))
        f[is.na(f)] <- 0
        ZY[, y] <- ZY[, y] + comp$b * f
      }
    }
  }
  ## back to normal scores, so the outcome keeps its original distribution
  for (y in outcomes) ZY[, y] <- normal_scores(ZY[, y])
  list(Z = cbind(ZX, ZY), cats = cats)
}

## pick n_eng / n_ger responses (ids) of a corpus with a language column
## (if one language has too few responses, the other language makes up for
## them, so the number of analysed participants stays the same)
pick_by_language <- function(corpus, n_lang) {
  avail   <- sapply(names(n_lang), function(l) sum(corpus$language == l))
  need    <- sum(n_lang)
  n_lang  <- pmin(n_lang, avail)
  deficit <- need - sum(n_lang)
  for (l in names(n_lang)) {
    add <- min(deficit, avail[[l]] - n_lang[[l]])
    n_lang[[l]] <- n_lang[[l]] + add
    deficit <- deficit - add
  }
  if (deficit > 0) stop("corpus has too few responses: ", need - deficit, " of ", need)
  message("  responses by language: ", paste(names(n_lang), n_lang, collapse = ", "))
  unlist(lapply(names(n_lang), function(l) {
    sort(sample(corpus$id[corpus$language == l], n_lang[[l]]))
  }))
}

flow_counts <- function(x) {   # "eng: 526" -> c(eng = 526)
  setNames(as_count(sub("^.*: ", "", x)), sub(":.*$", "", x))
}

## =====================================================================================
## APEQ
## =====================================================================================
generate_apeq <- function() {
  set.seed(GEN_SEED + 1)
  spec   <- read_spec("APEQ")
  corpus <- read_corpus("apeq_text")
  corpus$text <- to_latin1_safe(corpus$text)
  if (anyDuplicated(trimws(gsub("\\s+", " ", corpus$text)))) stop("APEQ: duplicated responses")

  ## analysed participants: one response each
  n_txt <- flow_counts(spec$flow$with_text_by_language)
  ids   <- pick_by_language(corpus, n_txt)
  ctext <- corpus[match(ids, corpus$id), ]
  ctext <- ctext[sample(nrow(ctext)), ]               # order of the rows in the file
  Z <- draw_participants(spec, "APEQ", ctext$language, list(text = ctext))

  ## included participants without a response, and excluded participants
  n_incl <- flow_counts(spec$flow$after_exclusion_by_language) - table(factor(ctext$language, c("eng", "ger")))
  n_raw  <- flow_counts(spec$flow$raw_by_language)
  n_excl <- n_raw - flow_counts(spec$flow$after_exclusion_by_language)
  lang_other <- c(rep(names(n_incl), n_incl), rep(names(n_excl), n_excl))
  Z2 <- draw_participants(spec, "APEQ", lang_other)

  numeric_vars <- names(spec$numeric)
  cat_vars     <- c("Gender", "PsychedelicUsed", "Education3")
  v1 <- fill_values(Z, spec, numeric_vars, cat_vars)
  v2 <- fill_values(Z2, spec, numeric_vars, cat_vars)
  v  <- lapply(names(v1), function(k) c(v1[[k]], v2[[k]])); names(v) <- names(v1)
  n1 <- nrow(Z$Z); n <- n1 + nrow(Z2$Z)
  lang <- c(ctext$language, lang_other)
  excluded <- c(rep(0L, n1 + sum(n_incl)), rep(1L, sum(n_excl)))

  ## raw codes
  gender_code <- c(Female = 1, Male = 2, Other = 3)
  subst_code  <- c(LSD = 1, Psilocybin = 2, Mescaline = 3, Ayahuasca = 4)
  edu_tab     <- spec$categorical$Education_raw$table
  ## CASMIN code within the Education3 group (shares of the listed codes;
  ## a group without listed codes gets one of its codes at random)
  edu_groups  <- list(Primary = 1:3, Intermediate = 4:7, Higher = 8:9)
  edu_codes   <- suppressWarnings(as.integer(edu_tab$level))
  edu_share   <- as_count(edu_tab$n)
  education   <- vapply(v$Education3, function(g) {
    cand <- which(edu_codes %in% edu_groups[[g]])
    if (!length(cand)) return(as.numeric(sample(edu_groups[[g]], 1)))
    as.numeric(edu_codes[cand][sample.int(length(cand), 1, prob = edu_share[cand])])
  }, numeric(1))

  ## participants who are not analysed have some missing answers, as in the
  ## original file (blank = missing)
  blank <- function(x, rows, p = 0.09) { x[rows & runif(length(x)) < p] <- NA; x }
  not_analysed <- seq_len(n) > n1

  cols <- list(
    Exclusion = sprintf("%d", excluded),
    Sprache   = lang,
    Dose      = fmt_int_raw(blank(v$Dose, not_analysed)),
    Strength  = fmt_int_raw(blank(v$Strength, not_analysed)),
    Duration  = fmt_int_raw(blank(v$Duration, not_analysed)),
    Valence   = fmt_int_raw(blank(v$Valence, not_analysed)),
    retrospectiveappraisal = fmt_int_raw(blank(v$retrospectiveappraisal, not_analysed)),
    Mood         = fmt_int_raw(blank(v$Mood, not_analysed)),
    Preparedness = fmt_int_raw(blank(v$Preparedness, not_analysed)),
    Factor1_Therapeutic = fmt_deccomma(blank(v$Factor1_Therapeutic, not_analysed, 0.12)),
    Factor2_Escapist    = fmt_deccomma(blank(v$Factor2_Escapist, not_analysed, 0.12)),
    Factor3_Hedonic     = fmt_deccomma(blank(v$Factor3_Hedonic, not_analysed, 0.12)),
    EBI_Total = fmt_int_raw(blank(v$EBI_Total, not_analysed)),
    CEQ_Total = fmt_int_raw(blank(v$CEQ_Total, not_analysed)),
    WHOdiff   = fmt_int_raw(blank(v$WHOdiff, not_analysed)),
    AAQdiff   = fmt_int_raw(blank(v$AAQdiff, not_analysed)),
    "Age...Jahre" = fmt_int_raw(v$`Age...Jahre`),
    APEQ_AVPE = fmt_int_raw(blank(v$APEQ_AVPE, not_analysed)),
    APEQ_ACPE = fmt_int_raw(blank(v$APEQ_ACPE, not_analysed)),
    Gender          = fmt_int_raw(gender_code[v$Gender]),
    PsychedelicUsed = fmt_int_raw(subst_code[v$PsychedelicUsed]),
    Education       = fmt_int_raw(education),
    SelectedImpactFreeNennung1 = csv_quote(c(ctext$text, rep(" ", n - n1)))
  )
  cells <- do.call(cbind, cols)
  ## rows in random order (analysed and other participants mixed)
  cells <- cells[sample(nrow(cells)), , drop = FALSE]
  cells <- rbind(names(cols), cells)                 # header row (read with header = FALSE)
  write_csv2_latin1(cells, file.path(DATA_RAW, RAW_FILES$APEQ))
  invisible(TRUE)
}

## =====================================================================================
## GCMQ
## =====================================================================================
generate_gcmq <- function() {
  set.seed(GEN_SEED + 2)
  spec <- read_spec("GCMQ")
  ev   <- read_corpus("gcmq_events")
  he   <- read_corpus("gcmq_health")
  if (!identical(ev$id, he$id) || !identical(ev$language, he$language)) {
    stop("GCMQ: events and health files must have the same ids and languages in the same order")
  }
  ev$text <- to_latin1_safe(ev$text)
  he$text <- to_latin1_safe(he$text)

  n_txt <- flow_counts(spec$flow$with_both_texts_by_language)
  ids   <- pick_by_language(ev, n_txt)
  ids   <- sample(ids)
  e <- ev[match(ids, ev$id), ]; h <- he[match(ids, he$id), ]
  Z <- draw_participants(spec, "GCMQ", e$language, list(events = e, health = h))

  n_raw   <- flow_counts(spec$flow$raw_by_language)
  n_other <- n_raw - table(factor(e$language, c("eng", "ger")))
  lang_other <- rep(names(n_other), n_other)
  Z2 <- draw_participants(spec, "GCMQ", lang_other)

  numeric_vars <- names(spec$numeric)
  cat_vars     <- setdiff(names(spec$categorical), "Language")
  v1 <- fill_values(Z, spec, numeric_vars, cat_vars)
  v2 <- fill_values(Z2, spec, numeric_vars, cat_vars)
  v  <- lapply(names(v1), function(k) c(v1[[k]], v2[[k]])); names(v) <- names(v1)
  n1 <- nrow(Z$Z); n <- n1 + nrow(Z2$Z)
  lang <- c(e$language, lang_other)

  ## GCMQ_RE (not a predictor; reported as missing for many participants)
  rc <- spec$raw_columns
  re_na <- as.numeric(rc$NA_share_raw_file[rc$column == "GCMQ_RE"])
  gcmq_re <- qmap(rnorm(n), spec$numeric$GCMQ_RA)
  gcmq_re[runif(n) < re_na] <- NA

  ## raw columns: model variable -> raw column name
  raw_of <- setNames(rc$column, rc$model_variable)
  cols <- list(LANGUAGE = lang)
  for (mv in c(numeric_vars, cat_vars)) {
    col <- raw_of[[mv]]
    x   <- v[[mv]]
    if (mv %in% cat_vars) {
      tab <- spec$categorical[[mv]]$table
      oth <- x == "other"
      if (any(oth)) x[oth] <- other_codes(tab, sum(oth))
      x <- as.numeric(x)
    }
    cols[[col]] <- if (mv %in% c("Int_Ther", "Int_Hedo", "Int_Esca")) fmt_deccomma(x) else fmt_int_raw(x)
  }
  cols$GCMQ_RE <- fmt_int_raw(gcmq_re)

  ## free text: mostly in the later item (MH06_01 / MH07_01), some in the
  ## earlier one (MH05x01 / MH04x01), as after the questionnaire change
  early <- runif(n1) < 0.05
  blank_n <- rep(" ", n - n1)
  cols$MH05x01 <- csv_quote(c(ifelse(early, e$text, " "), blank_n))
  cols$MH06_01 <- csv_quote(c(ifelse(early, " ", e$text), blank_n))
  cols$MH04x01 <- csv_quote(c(ifelse(early, h$text, " "), blank_n))
  cols$MH07_01 <- csv_quote(c(ifelse(early, " ", h$text), blank_n))

  cells <- do.call(cbind, cols)
  cells <- cells[sample(nrow(cells)), , drop = FALSE]
  cells <- rbind(names(cols), cells)
  write_csv2_latin1(cells, file.path(DATA_RAW, RAW_FILES$GCMQ))
  invisible(TRUE)
}

## =====================================================================================
## PTSD
## =====================================================================================
generate_ptsd <- function() {
  set.seed(GEN_SEED + 3)
  spec <- read_spec("PTSD")
  ac <- read_corpus("ptsd_acute"); po <- read_corpus("ptsd_post"); tr <- read_corpus("ptsd_treat")
  if (!identical(ac$id, po$id) || !identical(ac$id, tr$id) ||
      !identical(ac$language, po$language) || !identical(ac$language, tr$language)) {
    stop("PTSD: acute, post and treat files must have the same ids and languages in the same order")
  }
  n <- spec$flow$raw
  if (nrow(ac) != n) stop("PTSD: ", nrow(ac), " participants in the corpus, ", n, " expected")
  ord <- sample(n)
  ac <- ac[ord, ]; po <- po[ord, ]; tr <- tr[ord, ]
  for (g in c("ac", "po", "tr")) {
    d <- get(g); d$text <- to_ascii(d$text); assign(g, d)
  }
  empty_post  <- po$text == ""
  empty_treat <- tr$text == ""
  empty_any   <- empty_post | empty_treat | ac$text == ""
  ## theme scores of empty responses do not exist
  po_s <- po; po_s[empty_post, setdiff(names(po), c("id", "language", "text"))] <- NA
  tr_s <- tr; tr_s[empty_treat, setdiff(names(tr), c("id", "language", "text"))] <- NA

  Z <- draw_participants(spec, "PTSD", ac$language, list(acute = ac, post = po_s, treat = tr_s))

  numeric_vars <- names(spec$numeric)
  cat_vars     <- c("Gender", "Country", "Edu", grep("^subs_", names(spec$categorical), value = TRUE))
  v <- fill_values(Z, spec, numeric_vars, cat_vars)

  rc <- spec$raw_columns
  raw_of <- setNames(rc$column, rc$model_variable)
  out <- data.frame(LANGUAGE = ac$language, stringsAsFactors = FALSE)
  for (mv in setdiff(c(numeric_vars, cat_vars), "Language")) {
    col <- if (mv %in% c("Country", "Edu")) tolower(mv) else raw_of[[mv]]
    x   <- v[[mv]]
    if (mv %in% cat_vars) {
      ## pooled levels: rare raw codes ("other" in the model-level table; 999 =
      ## the pipeline's own pooling code, also drawn as rare raw codes)
      tab <- spec$categorical[[if (mv %in% c("Country", "Edu")) paste0(tolower(mv), "_raw") else mv]]$table
      oth <- x %in% c("other", "999")
      if (any(oth)) x[oth] <- other_codes(tab, sum(oth))
      x <- as.numeric(x)
    }
    out[[col]] <- x
  }
  out$subs_DOM <- 0; out$subs_DOI <- 0; out$subs_other_text <- ""

  ## missing values as in the original: PTGI missing for the participants with
  ## an empty response and a few others; one missing predictor (age)
  n_ptgi <- spec$flow$PTGI_with_outcome
  no_ptgi <- which(empty_any)
  no_ptgi <- c(no_ptgi, sample(setdiff(seq_len(n), no_ptgi), n - n_ptgi - length(no_ptgi)))
  out$ptgi_sum[no_ptgi] <- NA
  n_miss_pred <- spec$flow$participants_lacking_a_nontext_predictor
  out$age[sample(which(!empty_any & !is.na(out$ptgi_sum)), n_miss_pred)] <- NA

  out$text_acute     <- ac$text
  out$text_postacute <- po$text
  out$text_treat     <- tr$text
  write_sav(out, file.path(DATA_RAW, RAW_FILES$PTSD))
  invisible(TRUE)
}

## =====================================================================================
dir.create(DATA_RAW, showWarnings = FALSE, recursive = TRUE)
for (d in if (exists("GENERATE_ONLY")) GENERATE_ONLY else c("APEQ", "GCMQ", "PTSD")) {
  message("generating synthetic ", d, " data ...")
  switch(d, APEQ = generate_apeq(), GCMQ = generate_gcmq(), PTSD = generate_ptsd())
}
