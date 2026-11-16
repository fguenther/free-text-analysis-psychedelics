## ---------------------------------------------------------------------------
## check_corpus.R
##
## Checks the synthetic free-text corpus in synthetic/texts/ (see CODEBOOK.md):
## counts, language shares, length quantiles against the targets, duplicates,
## id alignment across response types and theme-score distributions.
##
## Run from the repository root:
##   Rscript synthetic/texts/check_corpus.R
## Exits with status 1 if any check fails.
## ---------------------------------------------------------------------------

dir <- "synthetic/texts"

## --- targets ---------------------------------------------------------------
probs <- c(.10, .25, .50, .75, .90, .99)
targets <- list(
  apeq_text   = list(n = 960, empty = 0,  ger = .45, q = c(37, 64, 113, 198, 330, 750),
                     themes = c("pos_affect", "insight", "acceptance", "challenging", "mystical",
                                "sensory", "social", "therapeutic", "setting")),
  gcmq_events = list(n = 605, empty = 0,  ger = .34, q = c(69, 121, 241, 455, 824, 1024),
                     themes = c("calm_coping", "perspective", "acceptance", "self_insight",
                                "tools", "social", "no_change", "negative")),
  gcmq_health = list(n = 605, empty = 0,  ger = .34, q = c(42, 99, 200, 390, 724, 1024),
                     themes = c("euphoria_love", "open_mind", "appreciation", "symptom_relief",
                                "self_understanding", "indifference", "short_lived",
                                "no_impact", "negative")),
  ptsd_acute  = list(n = 243, empty = 0,  ger = .39, q = c(144, 398, 800, 1936, 3368, 9000),
                     themes = c("fear_panic", "ego_dissolution", "loss_control",
                                "entities_visions", "physical", "setting", "social_context",
                                "resolution")),
  ptsd_post   = list(n = 243, empty = 5,  ger = .39, q = c(25, 114, 252, 711, 1490, 6500),
                     themes = c("anxiety_panic", "dpdr", "depression", "hppd_visual",
                                "intrusive", "other_symptoms", "no_difficulty",
                                "self_insight")),
  ptsd_treat  = list(n = 243, empty = 10, ger = .39, q = c(11, 90, 256, 496, 891, 2200),
                     themes = c("therapy", "integration", "self_care", "medication", "time",
                                "psychedelics_again", "helped", "still_struggling", "no_need"))
)
## tolerances
TOL_GER  <- 0.05   # absolute deviation of the German share
TOL_MED  <- 0.25   # relative deviation of the median length
TOL_Q    <- 0.50   # relative deviation of the other length quantiles (warning only)
MAX_CHAR <- c(gcmq_events = 1100, gcmq_health = 1100)  # GCMQ answers were capped

failures <- character(0)
fail <- function(...) { msg <- paste0(...); failures <<- c(failures, msg); cat("  FAIL:", msg, "\n") }
warn <- function(...) cat("  warn:", paste0(...), "\n")

read_type <- function(type) {
  files <- sort(list.files(dir, pattern = paste0("^", type, "_[0-9]+\\.csv$"), full.names = TRUE))
  if (!length(files)) return(NULL)
  parts <- lapply(files, function(f) {
    d <- tryCatch(read.csv(f, encoding = "UTF-8", fileEncoding = "UTF-8", stringsAsFactors = FALSE,
                           colClasses = c(id = "character", language = "character", text = "character"),
                           na.strings = character(0)),
                  error = function(e) { fail(basename(f), ": cannot be read (", conditionMessage(e), ")"); NULL })
    if (!is.null(d)) d$file <- basename(f)
    d
  })
  parts <- parts[!vapply(parts, is.null, logical(1))]
  cols <- lapply(parts, function(d) setdiff(names(d), "file"))
  ref  <- c("id", "language", "text", targets[[type]]$themes)
  for (i in seq_along(parts)) if (!identical(cols[[i]], ref))
    fail(parts[[i]]$file[1], ": columns are ", paste(cols[[i]], collapse = ","))
  do.call(rbind, parts[vapply(cols, identical, logical(1), ref)])
}

corpus <- list()
for (type in names(targets)) {
  tg <- targets[[type]]
  cat("\n==", type, "==\n")
  d <- read_type(type)
  if (is.null(d) || !nrow(d)) { fail(type, ": no files"); next }
  corpus[[type]] <- d
  empty <- d$text == ""
  len   <- nchar(d$text[!empty])

  ## counts
  cat(sprintf("  rows %d (target %d), empty %d (target %d), files %d\n",
              nrow(d), tg$n, sum(empty), tg$empty, length(unique(d$file))))
  if (nrow(d) != tg$n) fail(type, ": ", nrow(d), " rows, target ", tg$n)
  if (sum(empty) != tg$empty) fail(type, ": ", sum(empty), " empty texts, target ", tg$empty)
  if (anyDuplicated(d$id)) fail(type, ": duplicated ids ", paste(head(d$id[duplicated(d$id)]), collapse = ", "))

  ## language
  if (!all(d$language %in% c("eng", "ger"))) fail(type, ": language not eng/ger in ", sum(!d$language %in% c("eng", "ger")), " rows")
  ger <- mean(d$language == "ger")
  cat(sprintf("  German share %.3f (target %.2f)\n", ger, tg$ger))
  if (abs(ger - tg$ger) > TOL_GER) fail(type, sprintf(": German share %.3f, target %.2f", ger, tg$ger))

  ## lengths
  q <- quantile(len, probs, names = FALSE)
  tab <- rbind(observed = round(q), target = tg$q)
  colnames(tab) <- paste0(probs * 100, "%")
  print(tab)
  cat(sprintf("  max %d, mean %.0f, total %d characters\n", max(len), mean(len), sum(len)))
  if (abs(q[3] / tg$q[3] - 1) > TOL_MED) fail(type, sprintf(": median length %.0f, target %d", q[3], tg$q[3]))
  off <- which(abs(q / tg$q - 1) > TOL_Q)
  if (length(off)) warn("length quantiles off by >", TOL_Q * 100, "%: ", paste(colnames(tab)[off], collapse = ", "))
  if (type %in% names(MAX_CHAR) && max(len) > MAX_CHAR[[type]])
    fail(type, ": texts longer than ", MAX_CHAR[[type]], " characters (", sum(len > MAX_CHAR[[type]]), ")")

  ## duplicates
  txt <- d$text[!empty]
  norm <- trimws(tolower(gsub("[[:space:][:punct:]]+", " ", txt)))
  if (anyDuplicated(txt)) fail(type, ": ", sum(duplicated(txt)), " exact duplicate texts")
  else if (anyDuplicated(norm)) fail(type, ": ", sum(duplicated(norm)), " texts duplicated up to case/punctuation")
  else cat("  duplicates: none\n")

  ## theme scores
  sc <- as.matrix(d[, tg$themes])
  if (!is.numeric(sc) || anyNA(sc) || !all(sc %in% 0:3)) fail(type, ": theme scores must be integers 0-3")
  else {
    dist <- t(vapply(tg$themes, function(th) tabulate(sc[, th] + 1, 4), integer(4)))
    colnames(dist) <- paste0("s", 0:3)
    dist <- cbind(dist, mean = round(colMeans(sc), 2))
    print(dist)
    nz <- rowSums(sc[!empty, , drop = FALSE] > 0)
    cat("  themes > 0 per response:", paste(names(table(nz)), table(nz), sep = ":", collapse = "  "), "\n")
    ## a few "nothing changed" answers without any theme are realistic
    if (mean(nz == 0) > 0.05) fail(type, ": ", sum(nz == 0), " non-empty texts without any theme (> 5%)")
    if (any(rowSums(sc[empty, , drop = FALSE]) > 0)) fail(type, ": empty texts with non-zero scores")
    never <- tg$themes[colSums(sc) == 0]
    if (length(never)) fail(type, ": themes never used: ", paste(never, collapse = ", "))
  }
}

## --- alignment across types of the same person ----------------------------
cat("\n== alignment ==\n")
same_people <- function(a, b) {
  x <- corpus[[a]]; y <- corpus[[b]]
  if (is.null(x) || is.null(y)) return(invisible())
  if (!identical(x$id, y$id)) fail(a, " / ", b, ": ids differ or are in a different order")
  else if (!identical(x$language, y$language)) fail(a, " / ", b, ": language differs for ", sum(x$language != y$language), " persons")
  else cat("  ", a, "/", b, ": ids and languages aligned\n")
}
same_people("gcmq_events", "gcmq_health")
same_people("ptsd_acute", "ptsd_post")
same_people("ptsd_acute", "ptsd_treat")
if (!is.null(corpus$ptsd_post) && !is.null(corpus$ptsd_treat) &&
    identical(corpus$ptsd_post$id, corpus$ptsd_treat$id)) {
  ep <- corpus$ptsd_post$text == ""; et <- corpus$ptsd_treat$text == ""
  cat(sprintf("  PTSD: %d persons with at least one empty response (%d post, %d treat)\n",
              sum(ep | et), sum(ep), sum(et)))
}

cat("\n")
if (length(failures)) {
  cat(length(failures), "check(s) failed.\n")
  if (!interactive()) quit(status = 1)
} else cat("All checks passed.\n")
