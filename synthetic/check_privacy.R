## ---------------------------------------------------------------------------
## check_privacy.R  (private step: run in the private repository)
##
## Checks that no synthetic response (synthetic/texts/) reproduces a real
## participant response, before the corpus is published:
##   1. exact matches (after normalising case, punctuation and whitespace)
##   2. shared word sequences: any run of SHINGLE_WORDS consecutive words that
##      occurs in a real response of the same dataset (10 words: shorter runs
##      are everyday phrases such as "for the first time in my life")
##   3. semantic near-copies: cosine similarity of the e5 embeddings of each
##      synthetic response with every real response of the same response type
##      above the level at which DIFFERENT real participants' responses are to
##      each other (the COSINE_QUANTILE of every real response's cosine to its
##      nearest other real response; e5 places any two texts on the same topic
##      above .9). Real embeddings: data/embeddings/e5_*.rds; synthetic
##      embeddings: the e5_*.rds files of a synthetic run, folder given as the
##      first argument.
## Short responses (fewer than MIN_WORDS words, e.g. "Mehr Gelassenheit") are
## reported in checks 1 and 3 only as information: identical short phrases are
## expected and identify nobody.
##
##   Rscript synthetic/check_privacy.R <folder with synthetic e5_*.rds>
##
## Writes synthetic/privacy_report.md (aggregate, no real text) and lists the
## flagged synthetic responses (synthetic text only) for rewriting.
## ---------------------------------------------------------------------------

SHINGLE_WORDS   <- 10
COSINE_QUANTILE <- 0.99
MIN_WORDS       <- 5

source("R/config.R"); source("R/embed.R"); source("R/datasets.R")
syn_emb_dir <- commandArgs(TRUE)[1]
if (is.na(syn_emb_dir)) stop("usage: Rscript synthetic/check_privacy.R <folder with synthetic e5_*.rds>")

## normalised for comparison; umlauts transliterated as in the synthetic PTSD
## file (generate.R), so that synthetic texts can be found in its embeddings
norm <- function(x) {
  x <- tolower(strip_prefix(x))
  map <- c("ä" = "ae", "ö" = "oe", "ü" = "ue", "ß" = "ss")
  for (ch in names(map)) x <- gsub(ch, map[[ch]], x, fixed = TRUE)
  x <- chartr("éèêàâçñóôíúáëï",
              "eeeaacnooiuaei", x)
  x <- iconv(x, "UTF-8", "ASCII", sub = "")
  x <- gsub("<br>", " ", x, fixed = TRUE)
  x <- gsub("[^[:alnum:] ]", " ", x)
  trimws(gsub("\\s+", " ", x))
}
shingles <- function(x, k = SHINGLE_WORDS) {
  w <- strsplit(x, " ", fixed = TRUE)[[1]]
  if (length(w) < k) return(character())
  vapply(seq_len(length(w) - k + 1), function(i) paste(w[i:(i + k - 1)], collapse = " "), "")
}

read_syn <- function(stem) {
  f <- sort(list.files("synthetic/texts", paste0("^", stem, "_[0-9]+\\.csv$"), full.names = TRUE))
  d <- do.call(rbind, lapply(f, read.csv, fileEncoding = "UTF-8", colClasses = "character",
                             na.strings = character()))
  d[d$text != "", c("id", "text")]
}

## response types: synthetic corpus stem, real texts, cache entry
types <- list(
  list(stem = "apeq_text",   ds = "APEQ", group = "text"),
  list(stem = "gcmq_events", ds = "GCMQ", group = "events"),
  list(stem = "gcmq_health", ds = "GCMQ", group = "health"),
  list(stem = "ptsd_acute",  ds = "PTSD", group = "acute"),
  list(stem = "ptsd_post",   ds = "PTSD", group = "post"),
  list(stem = "ptsd_treat",  ds = "PTSD", group = "treat")
)

report  <- c("# Privacy check of the synthetic corpus", "",
             sprintf(paste("Shared word runs: %d words. Cosine threshold per response type: the %.0f%% quantile",
                           "of real responses' cosine to their nearest OTHER real response (e5).",
                           "Responses with < %d words: information only."),
                     SHINGLE_WORDS, 100 * COSINE_QUANTILE, MIN_WORDS), "",
             "| response type | synthetic | real | exact (long) | exact (short) | shared word runs | cosine threshold | cosine > threshold (long) | cosine > threshold (short) | max cosine |",
             "|---|---|---|---|---|---|---|---|---|---|")
flagged <- list()

for (t in types) {
  syn  <- read_syn(t$stem)
  real <- readRDS(embedding_file("e5", t$ds))[[t$group]]
  real_text <- unique(real$text[strip_prefix(real$text) != ""])
  sn <- norm(syn$text); rn <- norm(real_text)
  long <- lengths(strsplit(sn, " ")) >= MIN_WORDS

  exact <- sn %in% rn
  real_sh <- unique(unlist(lapply(rn, shingles)))
  sh_hit  <- vapply(sn, function(s) any(shingles(s) %in% real_sh), logical(1))

  ## embeddings of the synthetic responses (same strings as the pipeline embeds)
  syn_cache <- readRDS(file.path(syn_emb_dir, paste0("e5_", t$ds, ".rds")))[[t$group]]
  key <- function(x) norm(x)
  idx <- match(key(paste0(TEXT_PREFIX, syn$text)), key(syn_cache$text))
  real_emb <- real$embedding[match(real_text, real$text), , drop = FALSE]
  cos_max <- rep(NA_real_, nrow(syn))
  ok <- !is.na(idx)
  if (any(ok)) cos_max[ok] <- apply(syn_cache$embedding[idx[ok], , drop = FALSE] %*% t(real_emb), 1, max)

  ## reference: how close different real participants' (longer) responses are
  real_long <- lengths(strsplit(rn, " ")) >= MIN_WORDS
  rr <- real_emb[real_long, , drop = FALSE] %*% t(real_emb[real_long, , drop = FALSE])
  diag(rr) <- -Inf
  threshold <- unname(quantile(apply(rr, 1, max), COSINE_QUANTILE))
  near <- !is.na(cos_max) & cos_max > threshold

  report <- c(report, sprintf("| %s | %d | %d | %d | %d | %d | %.3f | %d | %d | %.3f |",
                              t$stem, nrow(syn), length(real_text), sum(exact & long), sum(exact & !long),
                              sum(sh_hit), threshold, sum(near & long), sum(near & !long),
                              max(cos_max, na.rm = TRUE)))
  if (sum(!ok)) report <- c(report, sprintf("| (%d synthetic responses not in the synthetic run, not checked by cosine) ||||||||||", sum(!ok)))
  bad <- (exact & long) | sh_hit | (near & long)
  if (any(bad)) flagged[[t$stem]] <- data.frame(type = t$stem, id = syn$id[bad],
                                                exact = exact[bad], shingle = sh_hit[bad],
                                                cosine = round(cos_max[bad], 3),
                                                synthetic_text = syn$text[bad])
}

fl <- do.call(rbind, flagged)
report <- c(report, "", if (is.null(fl)) "**No synthetic response is flagged.**" else
  sprintf("**%d synthetic response(s) flagged for rewriting** (see synthetic/privacy_flagged.csv; synthetic text only).", nrow(fl)))
writeLines(enc2utf8(report), "synthetic/privacy_report.md", useBytes = TRUE)
if (!is.null(fl)) write.csv(fl, "synthetic/privacy_flagged.csv", row.names = FALSE, fileEncoding = "UTF-8")
cat(report, sep = "\n")
