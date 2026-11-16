## ---------------------------------------------------------------------------
## export_tex.R
##
## Writes everything the manuscript reads into tex/generated/. Nothing in there
## is ever edited by hand; floats, captions and labels stay in the manuscript.
##
##   results.tex                    every number in the text, as \res{<key>}
##   tab_summary_<emb>.tex          Table 1 (tabular only)
##   tab_overlap_<emb>.tex          overlap of text and other predictors (tabular only)
##   tab_models_<emb>_<ds>_<out>.tex all models of one analysis (tabular only)
##   tab_examples_<emb>_<ds>_<out>.tex  example responses (table ROWS plus
##                                  the closing \hline, to be \input as the
##                                  last thing inside the manuscript's
##                                  tabular/longtable)
##   tab_examples_<...>_en.tex      the same with German responses translated
##                                  (EXAMPLES_TRANSLATED, TRANSLATIONS_FILE)
##
## Keys of results.tex are <embedding>.<dataset>.<outcome>.<model>.<statistic>
## in lower case with "-" instead of "_", e.g. e5.apeq.who.none.r2,
## e5.ptsd.pcl.post+treat.delta or n.apeq.after-exclusion-language.ger.
## Every key with its value is listed in tex/generated/results.tex.
##
## The main results are those of the repeated nested CV (nested.R): keys
## without suffix (e.g. e5.apeq.who.text.r2, ....delta, ....p) and Tables 1
## and tab_models. The single 10-fold CV run (models.R) has the suffix
## ".single" (e.g. e5.apeq.who.text.single.r2, e5.apeq.who.singlebest.delta);
## the nprin sweep (".sweepbest") and the example responses come from it.
## Without the nested results (RUN_NESTED = FALSE) the main keys and tables
## are not written.
## ---------------------------------------------------------------------------

OUTCOME_LABELS <- c(WHO = "WHO-5", AAQ = "AAQ-II", WEMWBS = "WEMWBS",
                    PCL = "PCL-5", PTGI = "PTGI")

## --- number formatting ---------------------------------------------------------
## Values are written ready to typeset; the minus sign works in text and math.
tex_minus <- function(s) sub("^-", "\\\\ensuremath{-}", s)

## APA style: no leading zero for values bounded by 1 (R^2, r)
fmt_r2 <- function(x, digits = 3) {
  s <- formatC(round(x, digits), format = "f", digits = digits)
  s <- sub("^(-?)0\\.", "\\1.", s)
  tex_minus(ifelse(s %in% c("-.000", "-.00"), sub("-", "", s), s))
}
fmt_num <- function(x, digits = 2) tex_minus(formatC(round(x, digits), format = "f", digits = digits))
fmt_pct <- function(x, digits = 1) fmt_num(100 * x, digits)
fmt_int <- function(x) formatC(as.integer(x), format = "d", big.mark = "{,}")
fmt_sig <- function(x, digits = 3) tex_minus(format(signif(x, digits), scientific = FALSE, drop0trailing = TRUE))

## --- synthetic data: highlighting ---------------------------------------------------
## With SYNTHETIC = TRUE (config_data.R), every value the pipeline writes into
## the manuscript (\res values, number cells of the tables, example responses)
## is wrapped in \synth{...}, which results.tex defines as purple text, so the
## synthetic numbers stand out from the (unchanged) manuscript prose.
## results.tex then also defines \synthmismatch{...} (red), used by hand in the
## manuscript for sentences that do not fit the synthetic results.
## With SYNTHETIC = FALSE, hl() changes nothing.
hl <- function(x) {
  if (!isTRUE(SYNTHETIC)) return(x)
  out <- ifelse(x %in% c("", "--"), x, paste0("\\synth{", x, "}"))
  names(out) <- names(x)
  out
}

## Some responses contain windows-1252 punctuation that was decoded as
## latin1 (C1 control characters). The analysis keeps the strings as they
## were embedded; for display they are mapped to the intended characters.
CP1252_C1 <- c("\u0080" = "€", "\u0082" = "‚", "\u0084" = "„",
               "\u0085" = "…", "\u0091" = "‘", "\u0092" = "’",
               "\u0093" = "“", "\u0094" = "”", "\u0095" = "•",
               "\u0096" = "–", "\u0097" = "—", "\u0099" = "™")

tex_escape <- function(x) {
  for (ch in names(CP1252_C1)) x <- gsub(ch, CP1252_C1[[ch]], x, fixed = TRUE)
  x <- gsub("[\u0080-\u009f]", "", x)               # any other control characters
  x <- gsub("<br>", " ", x, fixed = TRUE)
  x <- gsub("\\", "\001", x, fixed = TRUE)          # placeholder for backslashes
  x <- gsub("([&%$#_{}])", "\\\\\\1", x)
  x <- gsub("~", "\\textasciitilde{}", x, fixed = TRUE)
  x <- gsub("^", "\\textasciicircum{}", x, fixed = TRUE)
  x <- gsub("\001", "\\textbackslash{}", x, fixed = TRUE)
  trimws(gsub("\\s+", " ", x))
}

## --- model labels ----------------------------------------------------------------
text_label <- function(groups) {
  ## APEQ has a single free-text response
  if (identical(groups, "text")) "text" else paste(groups, collapse = " + ")
}
table_model_label <- function(id, groups) {
  if (id == "none") return("baseline")
  if (id == "text_only") return(paste0("text only (", text_label(groups), ")"))
  paste("+", gsub("+", " + ", id, fixed = TRUE))
}
key_model <- function(id) gsub("_", "", id)   # text_only -> textonly

## --- collecting the results ---------------------------------------------------------
load_results <- function() {
  res <- lapply(seq_len(nrow(ANALYSES)), function(i) {
    a <- ANALYSES[i, ]
    readRDS(result_file(a$embedding, a$dataset, a$outcome))
  })
  names(res) <- paste(ANALYSES$embedding, ANALYSES$dataset, ANALYSES$outcome, sep = "/")
  res
}

## models with other predictors AND text
extended <- function(df) df[!df$model %in% c("none", "text_only"), ]

## the free-text responses of an analysis
analysis_groups <- function(r) {
  unique(unlist(strsplit(extended(r$main)$model, "+", fixed = TRUE)))
}

## summary of one analysis: best extended model at NPRIN and over the sweep
summarise_analysis <- function(r) {
  main <- r$main
  base <- main$r2[main$model == "none"]
  ext  <- extended(main)
  best <- ext[which.max(ext$r2), ]
  sw     <- r$sweep
  sw_ext <- extended(sw)
  sw_best <- sw_ext[which.max(sw_ext$r2), ]
  sw_txt  <- sw[sw$model == "text_only", ]
  sw_txt  <- sw_txt[which.max(sw_txt$r2), ]
  list(base = base, best = best, sweep_best = sw_best,
       text_only = main[main$model == "text_only", ], sweep_text_only = sw_txt)
}

## number of model terms per block; an interaction term (APEQ ACE x AVE)
## counts as one predictor of the block of its variables
count_predictors <- function(r) {
  terms  <- attr(terms(reformulate(r$sample$predictors)), "term.labels")
  first  <- sub(":.*", "", terms)
  blocks <- lapply(r$sample$predictor_blocks, function(b) sum(first %in% b))
  c(blocks, total = sum(unlist(blocks)))
}

## --- results.tex -----------------------------------------------------------------------
build_results <- function(res) {
  vals <- list()
  ## keys: lower case, "-" instead of "_" (safe in text and math mode)
  add <- function(key, value) vals[[gsub("_", "-", tolower(key))]] <<- value

  ## analysis settings
  add("set.seed", as.character(SEED))
  add("set.folds", as.character(N_FOLDS))
  add("set.nprin", as.character(NPRIN))
  add("set.alpha.n", as.character(length(unique(TUNE_GRID$alpha))))
  add("set.lambda.n", as.character(length(unique(TUNE_GRID$lambda))))
  add("set.lambda.min", sprintf("10^{%d}", round(log10(min(TUNE_GRID$lambda)))))
  add("set.lambda.max", sprintf("10^{%d}", round(log10(max(TUNE_GRID$lambda)))))
  add("set.examples", as.character(N_EXAMPLES))
  for (ds in names(NPRIN_GRID)) {
    add(paste0("set.sweep.", ds), paste(NPRIN_GRID[[ds]], collapse = ", "))
  }

  for (key in names(res)) {
    r  <- res[[key]]
    k  <- paste(r$embedding, r$dataset, r$outcome, sep = ".")
    kd <- paste(r$embedding, r$dataset, sep = ".")
    fl <- r$sample$flow

    ## sample sizes (dataset level: identical for both embeddings)
    if (r$embedding == names(EMBEDDING_MODELS)[1]) {
      kn <- paste0("n.", r$dataset)
      ## results cached before these counts were added to the sample flow
      ## (complete_sample) lack them: recompute them from the inputs
      if (is.null(fl$excluded_text)) {
        fx <- analysis_inputs(r$embedding, r$dataset, r$outcome)$sample$flow
        fl[c("excluded_text", "excluded_predictor")] <- fx[c("excluded_text", "excluded_predictor")]
      }
      for (nm in names(fl)) {
        v <- fl[[nm]]
        if (nm %in% c("with_outcome", "excluded_text", "excluded_predictor",
                      "analysed", "analysed_language")) {
          nm <- paste0(r$outcome, ".", nm)
        }
        if (length(v) == 1 && is.null(names(v))) {
          add(paste0(kn, ".", nm), fmt_int(v))
        } else {
          for (l in names(v)) add(paste0(kn, ".", nm, ".", l), fmt_int(v[[l]]))
        }
      }
      pc <- count_predictors(r)
      for (b in names(pc)) add(paste0("npred.", r$dataset, ".", b), as.character(pc[[b]]))
      if (!is.null(r$facts$cor_who_aaq)) add("apeq.cor.who.aaq", fmt_r2(r$facts$cor_who_aaq))
      if (!is.null(r$facts$gcmq_re_missing)) add("n.gcmq.gcmqre.missing", fmt_int(r$facts$gcmq_re_missing))
    }

    ## every model at NPRIN, single 10-fold CV run (key suffix ".single"; the
    ## main keys without suffix come from the nested CV, build_nested_results)
    base <- r$main$r2[r$main$model == "none"]
    for (i in seq_len(nrow(r$main))) {
      m  <- r$main[i, ]
      km <- paste(k, key_model(m$model), "single", sep = ".")
      add(paste0(km, ".r2"), fmt_r2(m$r2))
      add(paste0(km, ".alpha"), fmt_num(m$alpha, 1))
      add(paste0(km, ".lambda"), fmt_sig(m$lambda))
      if (m$model != "none") {
        add(paste0(km, ".delta"), fmt_r2(m$r2 - base))
        add(paste0(km, ".deltapct"), fmt_pct(m$r2 - base))
        add(paste0(km, ".relgain"), fmt_pct((m$r2 - base) / base))
      }
    }
    ## best over the sweep, per model
    for (id in setdiff(unique(r$sweep$model), "none")) {
      s <- r$sweep[r$sweep$model == id, ]
      s <- s[which.max(s$r2), ]
      km <- paste(k, key_model(id), "sweepbest", sep = ".")
      add(paste0(km, ".r2"), fmt_r2(s$r2))
      add(paste0(km, ".delta"), fmt_r2(s$r2 - base))
      add(paste0(km, ".nprin"), as.character(s$nprin))
    }

    ## summary of the single run: best extended model at NPRIN and over the sweep
    sm <- summarise_analysis(r)
    groups <- strsplit(sm$best$model, "+", fixed = TRUE)[[1]]
    add(paste0(k, ".singlebest.model"), text_label(groups))
    add(paste0(k, ".singlebest.r2"), fmt_r2(sm$best$r2))
    add(paste0(k, ".singlebest.delta"), fmt_r2(sm$best$r2 - sm$base))
    add(paste0(k, ".singlebest.deltapct"), fmt_pct(sm$best$r2 - sm$base))
    add(paste0(k, ".singlebest.relgain"), fmt_pct((sm$best$r2 - sm$base) / sm$base))
    add(paste0(k, ".sweepbest.model"),
        text_label(strsplit(sm$sweep_best$model, "+", fixed = TRUE)[[1]]))
    add(paste0(k, ".sweepbest.r2"), fmt_r2(sm$sweep_best$r2))
    add(paste0(k, ".sweepbest.delta"), fmt_r2(sm$sweep_best$r2 - sm$base))
    add(paste0(k, ".sweepbest.nprin"), as.character(sm$sweep_best$nprin))
    add(paste0(k, ".examples.model"), text_label(r$example_group))
    ## example responses left out for display (EXAMPLES_DROPPED, config_data.R)
    add(paste0(k, ".examples.ndropped"),
        as.character(length(EXAMPLES_DROPPED[[paste(r$embedding, r$dataset, r$outcome, sep = "/")]])))
  }
  vals
}

write_results_tex <- function(vals, file) {
  meta <- c(
    "% generated by R/export_tex.R -- do not edit by hand.",
    paste0("% run: ", format(Sys.time(), "%Y-%m-%d %H:%M")),
    "%",
    "% \\res{<key>} prints a value; an unknown key prints a red ??<key>.",
    "\\newcommand{\\res}[1]{\\ifcsname res@#1\\endcsname\\csname res@#1\\endcsname\\else\\textbf{\\textcolor{red}{??\\detokenize{#1}}}\\fi}",
    paste0("\\newcommand{\\resrundate}{", format(Sys.Date(), "%Y-%m-%d"), "}"),
    if (isTRUE(SYNTHETIC)) c(
      "% SYNTHETIC data: every value below is wrapped in \\synth (purple);",
      "% \\synthmismatch marks manuscript sentences that do not fit the synthetic results (red).",
      "\\providecommand{\\synth}[1]{\\textcolor[HTML]{7B1FA2}{#1}}",   # purple (xcolor's 'purple' looks magenta)
      "\\providecommand{\\synthmismatch}[1]{\\textcolor{red}{#1}}"
    ),
    ""
  )
  keys  <- sort(names(vals))
  lines <- sprintf("\\expandafter\\def\\csname res@%s\\endcsname{%s}", keys, hl(unlist(vals[keys])))
  writeLines(enc2utf8(c(meta, lines)), file, useBytes = TRUE)
}

## --- Table 1: summary ---------------------------------------------------------------
## R^2 values and the test of Delta R^2 from the nested CV; the extended model
## is the pre-specified one with all free-text responses (confirm_model)
write_summary_table <- function(res, nres, emb, file) {
  cols <- paste(emb, c("APEQ/WHO", "APEQ/AAQ", "GCMQ/WEMWBS", "PTSD/PCL", "PTSD/PTGI"), sep = "/")
  rr   <- res[cols]
  nn   <- nres[cols]
  ds   <- sapply(rr, `[[`, "dataset")

  ## one cell per outcome; identical values within a dataset are merged
  row <- function(label, values) {
    values <- hl(values)
    cells <- character(0)
    for (d in unique(ds)) {
      v <- values[ds == d]
      if (length(v) > 1 && length(unique(v)) == 1) {
        cells <- c(cells, sprintf("\\multicolumn{%d}{c}{%s}", length(v), v[1]))
      } else {
        cells <- c(cells, v)
      }
    }
    paste0(label, " & ", paste(cells, collapse = " & "), " \\\\")
  }
  pcs <- lapply(rr, count_predictors)
  nr2 <- function(n, m) n$main$r2[n$main$model == m]
  cft <- lapply(nn, function(n) n$tests[n$tests$model == confirm_model(n), ])

  lines <- c(
    "% generated by R/export_tex.R -- do not edit by hand.",
    "\\begin{tabular}{llllll}",
    "\\hline",
    "dataset & \\multicolumn{2}{c}{APEQ} & \\multicolumn{1}{c}{GCMQ} & \\multicolumn{2}{c}{PTSD} \\\\",
    "\\hline",
    paste0("outcome & ", paste(OUTCOME_LABELS[sapply(rr, `[[`, "outcome")], collapse = " & "), " \\\\"),
    "\\hdashline",
    row("$N$ analysed", sapply(rr, function(r) fmt_int(r$sample$flow$analysed))),
    row("\\# free-text responses", sapply(rr, function(r) as.character(length(analysis_groups(r))))),
    row("\\# other predictors", sapply(pcs, function(p) as.character(p$total))),
    row("-- demographic", sapply(pcs, function(p) as.character(p$demographic))),
    row("-- setting", sapply(pcs, function(p) as.character(p$setting))),
    row("-- questionnaires", sapply(pcs, function(p) as.character(p$questionnaire))),
    "\\hdashline",
    row("baseline model $R^2$", sapply(nn, function(n) fmt_r2(nr2(n, "none")))),
    row("baseline + text model $R^2$", sapply(nn, function(n) fmt_r2(nr2(n, confirm_model(n))))),
    row("$\\Delta R^2$", sapply(cft, function(t) fmt_r2(t$delta))),
    row("-- 95\\% CI", sapply(cft, function(t) sprintf("[%s, %s]", fmt_r2(t$ci_lo), fmt_r2(t$ci_hi)))),
    row("-- $t$ (df)", sapply(cft, function(t) sprintf("%s (%d)", fmt_num(t$t, 2), t$df))),
    row("-- $p$", sapply(cft, function(t) fmt_pval(t$p))),
    row("text-only model $R^2$", sapply(nn, function(n) fmt_r2(nr2(n, "text_only")))),
    "\\hline",
    "\\end{tabular}"
  )
  writeLines(enc2utf8(lines), file, useBytes = TRUE)
}

## --- all models of one analysis ---------------------------------------------------------
## nested CV: R^2, Delta R^2 vs. baseline with 95% CI and corrected t-test;
## the extended model with the largest Delta R^2 (nested_best) in boldface.
## Rows in the order of
## the single-run results (the model hierarchy).
write_models_table <- function(r, n, file) {
  groups <- analysis_groups(r)
  best   <- nested_best(n)$model
  rows <- vapply(r$main$model, function(id) {
    r2 <- fmt_r2(n$main$r2[n$main$model == id])
    t  <- n$tests[n$tests$model == id, ]
    cells <- c(table_model_label(id, groups), r2,
               if (id == "none") c(".000", "", "") else if (id == "text_only") c("\\emph{not nested}", "", "")
               else c(fmt_r2(t$delta), sprintf("[%s, %s]", fmt_r2(t$ci_lo), fmt_r2(t$ci_hi)), fmt_pval(t$p)))
    num <- seq_along(cells) > 1 & cells != "\\emph{not nested}"
    cells[num] <- hl(cells[num])
    if (id == best) cells <- ifelse(cells == "", "", paste0("\\textbf{", cells, "}"))
    paste0(paste(cells, collapse = " & "), " \\\\")
  }, character(1))
  lines <- c(
    "% generated by R/export_tex.R -- do not edit by hand.",
    "\\begin{tabular}{lrrcr}",
    "\\hline",
    "Model & $R^2$ & $\\Delta R^2$ vs. baseline & 95\\% CI & $p$ \\\\",
    "\\hline",
    rows,
    "\\hline",
    "\\end{tabular}"
  )
  writeLines(enc2utf8(lines), file, useBytes = TRUE)
}

## --- overlap of text data and other predictors (all datasets) -------------------------------
## One row per construct; the variable names per dataset (NA: not in that
## dataset). Every variable with a value in overlap_<emb>.rds must appear here.
OVERLAP_ROWS <- list(
  demographic = list(
    "Age"                            = c(APEQ = "Age...Jahre", GCMQ = "Age", PTSD = "Age"),
    "Stressful life events"  = c(GCMQ = "CumSLE"),
    "Mental disorder diagnosis"      = c(GCMQ = "Diagnosis"),
    "Depression diagnosis"           = c(GCMQ = "Depression")
  ),
  setting = list(
    "Dose"                           = c(APEQ = "Dose", GCMQ = "Dose", PTSD = "dose_exp"),
    "Strength"                       = c(APEQ = "Strength"),
    "Valence"                        = c(APEQ = "Valence", GCMQ = "Valence", PTSD = "valence"),
    "Retrospective appraisal"        = c(APEQ = "retrospectiveappraisal",
                                         GCMQ = "retrospectiveappraisal", PTSD = "evaluation_exp"),
    "Clarity of memory"              = c(GCMQ = "Clarity", PTSD = "clear_exp"),
    "Duration"                       = c(APEQ = "Duration", PTSD = "duration_exp"),
    "Mood"                           = c(APEQ = "Mood"),
    "Preparedness"                   = c(APEQ = "Preparedness"),
    "Challenge"                      = c(PTSD = "challenge"),
    "Suitability of setting"         = c(GCMQ = "Suitability"),
    "Setting: nature"                = c(GCMQ = "SettingNature"),
    "No concomitant substance"       = c(GCMQ = "conc_none"),
    "Number of psychedelics"         = c(PTSD = "subs_psy_count"),
    "Number of other substances"     = c(PTSD = "subs_others_count"),
    "Number of substances (total)"   = c(PTSD = "subs_count_all")
  ),
  questionnaire = list(
    "Therapeutic use motives"        = c(APEQ = "Factor1_Therapeutic", GCMQ = "Int_Ther"),
    "Self-exploration use motives"   = c(PTSD = "motive_selfexploration"),
    "Escapist use motives"           = c(APEQ = "Factor2_Escapist", GCMQ = "Int_Esca",
                                         PTSD = "motive_escapist"),
    "Hedonic use motives"            = c(APEQ = "Factor3_Hedonic", GCMQ = "Int_Hedo",
                                         PTSD = "motive_hedonic"),
    "APEQ-ACE"                       = c(APEQ = "APEQ_ACPE", GCMQ = "APEQ_ACE", PTSD = "apeq_ACE_mean"),
    "APEQ-AVE"                       = c(APEQ = "APEQ_AVPE", GCMQ = "APEQ_AVE", PTSD = "apeq_AVE_mean"),
    "EBI"                            = c(APEQ = "EBI_Total", GCMQ = "EBI"),
    "CEQ"                            = c(APEQ = "CEQ_Total", GCMQ = "CEQ", PTSD = "ceq_mean"),
    "ASC-OBE"                        = c(GCMQ = "ASC_OBE"),
    "GCMQ-RA"                        = c(GCMQ = "GCMQ_RA"),
    "GCMQ-PA"                        = c(GCMQ = "GCMQ_PA"),
    "GCMQ-CL"                        = c(GCMQ = "GCMQ_CL"),
    "GCMQ-MA"                        = c(GCMQ = "GCMQ_MA")
  )
)
OVERLAP_BLOCK_LABELS <- c(demographic = "Demographic", setting = "Setting",
                          questionnaire = "Questionnaires")

write_overlap_table <- function(emb, file) {
  o  <- readRDS(overlap_file(emb))
  v  <- o$variables
  ds <- c("APEQ", "GCMQ", "PTSD")

  mapped <- unlist(lapply(unlist(OVERLAP_ROWS, recursive = FALSE),
                          function(m) paste(names(m), m)))
  have <- paste(v$dataset, v$variable)[!is.na(v$r2)]
  if (length(setdiff(have, mapped))) {
    stop("overlap variables missing from OVERLAP_ROWS: ",
         paste(setdiff(have, mapped), collapse = ", "))
  }

  cell <- function(d, var) {
    if (is.na(var)) return("--")
    x <- v[v$dataset == d & v$variable == var, ]
    if (!nrow(x) || is.na(x$r2)) return("--")
    s <- hl(fmt_r2(x$r2))
    if (x$type == "binary") paste0(s, "$^{b}$") else s
  }
  body <- unlist(lapply(names(OVERLAP_ROWS), function(b) {
    rows <- vapply(names(OVERLAP_ROWS[[b]]), function(lab) {
      m <- OVERLAP_ROWS[[b]][[lab]]
      paste0("\\quad ", lab, " & ",
             paste(sapply(ds, function(d) cell(d, m[d])), collapse = " & "), " \\\\")
    }, character(1))
    c(sprintf("\\multicolumn{4}{l}{\\textit{%s}} \\\\", OVERLAP_BLOCK_LABELS[[b]]), rows)
  }))

  per_ds <- function(f) paste(sapply(ds, function(d) f(v[v$dataset == d, ])), collapse = " & ")
  s <- o$text_signal
  ## i = 1: main outcome, i = 2: secondary outcome of the dataset
  signal <- function(d, i) {
    x <- s[s$dataset == d, ]
    if (nrow(x) < i) return("--")
    sprintf("%s (%s)", hl(fmt_r2(x$adj_r2[i])), OUTCOME_LABELS[x$outcome[i]])
  }
  lines <- c(
    "% generated by R/export_tex.R -- do not edit by hand.",
    ## compact: with its note, the float has to fit one page in apa7's man mode
    "\\small\\renewcommand{\\arraystretch}{0.88}%",
    "\\begin{tabular}{lccc}",
    "\\hline",
    ## header: dataset and (if it has several) the free-text response used
    paste0(" & ", per_ds(function(x) {
      if (x$group[1] == "text") x$dataset[1] else sprintf("%s (%s)", x$dataset[1], x$group[1])
    }), " \\\\"),
    paste0("$N$ & ", per_ds(function(x) hl(fmt_int(x$n[1]))), " \\\\"),
    "\\hline",
    body,
    "\\hdashline",
    paste0("rare binary predictors (dropped) & ",
           per_ds(function(x) hl(as.character(sum(x$type == "binary_rare")))), " \\\\"),
    paste0("categorical predictors (not used) & ",
           per_ds(function(x) hl(as.character(sum(x$type == "multilevel")))), " \\\\"),
    "\\hdashline",
    paste0("text signal$^{t}$, main outcome & ",
           paste(sapply(ds, signal, i = 1), collapse = " & "), " \\\\"),
    paste0("text signal$^{t}$, secondary outcome & ",
           paste(sapply(ds, signal, i = 2), collapse = " & "), " \\\\"),
    "\\hline",
    "\\end{tabular}"
  )
  writeLines(enc2utf8(lines), file, useBytes = TRUE)
}

## --- example responses (rows only) ----------------------------------------------------------
## the example responses shown in the manuscript: the cached top N_EXAMPLES,
## or, if EXAMPLES_DROPPED lists responses for this analysis, the ranking
## recomputed from the stored held-out predictions without those responses
display_examples <- function(r) {
  drop <- EXAMPLES_DROPPED[[paste(r$embedding, r$dataset, r$outcome, sep = "/")]]
  if (!length(drop)) return(r$examples)
  inp <- analysis_inputs(r$embedding, r$dataset, r$outcome)
  ex  <- example_responses(list(pred = r$main_predictions$none),
                           list(pred = r$main_predictions[[r$example_group]]),
                           inp$sample$data[[inp$prep$text_cols[[r$example_group]]]],
                           n = N_EXAMPLES + length(drop))
  stopifnot(identical(ex[seq_len(N_EXAMPLES), ], r$examples))
  hit <- sapply(drop, function(s) startsWith(ex$response, s))
  if (any(colSums(hit) != 1)) {
    stop("EXAMPLES_DROPPED: each entry must match exactly one response: ",
         paste(drop[colSums(hit) != 1], collapse = " | "))
  }
  ex[rowSums(hit) == 0, ][seq_len(N_EXAMPLES), ]
}

## `text` is the (already typeset) response column; defaults to the responses
write_examples_rows <- function(r, file, ex = display_examples(r), text = tex_escape(ex$response),
                                note = "") {
  shift <- hl(fmt_num(ex$shift, 2))
  shift <- ifelse(ex$shift < 0, paste0("\\textbf{", shift, "}"), shift)
  rows <- sprintf("%s & %s & %s \\\\", hl(text), hl(fmt_num(ex$improvement, 2)), shift)
  ## The closing \hline is part of this file: after an \input, LaTeX cannot
  ## start a new table row with \hline, so nothing may follow the \input
  ## except \end{tabular} / \end{longtable}.
  lines <- c(
    paste0("% generated by R/export_tex.R -- do not edit by hand. Rows only (incl. the final \\hline); ",
           "response type: ", r$example_group, note),
    rows,
    "\\hline"
  )
  writeLines(enc2utf8(lines), file, useBytes = TRUE)
}

## --- English versions of the example tables (EXAMPLES_TRANSLATED) ------------------------------
## Responses are matched to TRANSLATIONS_FILE by dataset and text (whitespace
## normalised); the language of a response is that of its participant in the
## analysed sample.
norm_text <- function(x) gsub("\\s+", " ", trimws(x))

read_translations <- function() {
  if (!file.exists(TRANSLATIONS_FILE)) {
    return(data.frame(dataset = character(), original = character(), translation = character(),
                      key = character()))
  }
  tr <- read.csv(TRANSLATIONS_FILE, fileEncoding = "UTF-8", colClasses = "character")
  if (!identical(names(tr), c("dataset", "original", "translation"))) {
    stop(TRANSLATIONS_FILE, ": the columns must be dataset, original, translation")
  }
  tr$key <- paste(tr$dataset, norm_text(tr$original), sep = "\r")
  if (anyDuplicated(tr$key)) {
    stop(TRANSLATIONS_FILE, ": duplicated originals: ",
         paste(unique(tr$original[duplicated(tr$key)]), collapse = " | "))
  }
  tr
}

example_languages <- function(r, responses) {
  inp  <- analysis_inputs(r$embedding, r$dataset, r$outcome)
  d    <- inp$sample$data
  txt  <- strip_prefix(d[[inp$prep$text_cols[[r$example_group]]]])
  lang <- as.character(d[[inp$prep$language]])
  vapply(responses, function(s) {
    l <- unique(lang[txt == s])
    if (length(l) != 1) stop("example response with no or several languages in the sample: ", s)
    l
  }, character(1), USE.NAMES = FALSE)
}

## Checks every listed table first and stops with all missing translations
## at once (as ready-to-paste CSV rows); writes the files only if none is missing.
write_translated_examples <- function(res) {
  if (!length(EXAMPLES_TRANSLATED)) return(invisible())
  unknown <- setdiff(EXAMPLES_TRANSLATED, names(res))
  if (length(unknown)) stop("EXAMPLES_TRANSLATED: unknown analyses: ", paste(unknown, collapse = ", "))
  tr <- read_translations()
  tables  <- list()
  missing <- character()
  for (key in EXAMPLES_TRANSLATED) {
    r   <- res[[key]]
    ex  <- display_examples(r)
    src <- example_languages(r, ex$response) == TRANSLATE_LANGUAGE
    en  <- tr$translation[match(paste(r$dataset, norm_text(ex$response), sep = "\r"), tr$key)]
    gap <- src & (is.na(en) | trimws(en) == "")
    missing <- c(missing, sprintf("\"%s\",\"%s\",\"\"", r$dataset,
                                  gsub("\"", "\"\"", ex$response[gap], fixed = TRUE)))
    text <- tex_escape(ex$response)
    text[src] <- paste0(tex_escape(en[src]), "$^{\\dagger}$")
    tables[[key]] <- list(r = r, ex = ex, text = text, n = sum(src))
  }
  if (length(missing)) {
    stop(length(missing), " example response(s) in language '", TRANSLATE_LANGUAGE,
         "' have no translation. Add these rows to ", TRANSLATIONS_FILE,
         " and fill in the translation:\n", paste(unique(missing), collapse = "\n"), call. = FALSE)
  }
  for (t in tables) {
    stem <- paste(t$r$embedding, t$r$dataset, t$r$outcome, sep = "_")
    write_examples_rows(t$r, file.path(GENERATED_DIR, paste0("tab_examples_", stem, "_en.tex")),
                        ex = t$ex, text = t$text,
                        note = sprintf("; English version: %d response(s) translated from %s, marked with \\dagger",
                                       t$n, TRANSLATIONS_FILE))
  }
  invisible()
}

## --- repeated nested CV (nested.R): the main results ------------------------------------------
## keys (k = <emb>.<dataset>.<outcome>):
##   set.repeats, set.innerfolds
##   k.<model>.r2                 mean outer-fold R^2
##   k.<model>.{alpha,lambda}     median of the tuned values over the outer folds
##   k.<model>.nna                outer folds with constant predictions (no R^2)
##   k.<model>.{delta,deltapct,relgain,cilo,cihi,t,df,p,mcse}
##                                Delta R^2 vs. baseline (absolute, in %, relative
##                                gain in %), 95% CI and corrected t-test
##                                (extended models); p is typeset with its
##                                relation, e.g. "p = .012" or "p < .001"
##   k.confirm.*                  the pre-specified test: the extended model with
##                                all free-text responses (confirm_model)
##   k.best.*                     the extended model with the largest Delta R^2
##                                vs. baseline (nested_best; the same as the
##                                highest R^2 unless some outer folds have no
##                                R^2) -- descriptive, its p is not corrected
##                                for the selection
##   both with {model,r2,delta,deltapct,relgain,cilo,cihi,t,df,p}
fmt_p <- function(p) {
  if (p < .001) "\\ensuremath{p < .001}" else sprintf("\\ensuremath{p = %s}", fmt_r2(p))
}
## p alone, for table cells
fmt_pval <- function(p) if (p < .001) "$<$ .001" else fmt_r2(p)

## the pre-specified extended model: all free-text responses of the dataset
confirm_model <- function(n) {
  ext <- setdiff(n$main$model, c("none", "text_only"))
  ext[which.max(lengths(strsplit(ext, "+", fixed = TRUE)))]
}

load_nested <- function() {
  files <- mapply(nested_file, ANALYSES$embedding, ANALYSES$dataset, ANALYSES$outcome)
  if (!all(file.exists(files))) return(NULL)
  res <- lapply(files, readRDS)
  names(res) <- paste(ANALYSES$embedding, ANALYSES$dataset, ANALYSES$outcome, sep = "/")
  res
}

nested_best <- function(n) {
  t <- n$tests
  t[which.max(t$delta), ]
}

build_nested_results <- function(nres) {
  vals <- list()
  add <- function(key, value) vals[[gsub("_", "-", tolower(key))]] <<- value
  add("set.repeats", as.character(N_REPEATS))
  add("set.innerfolds", as.character(N_INNER_FOLDS))
  for (n in nres) {
    k    <- paste(n$embedding, n$dataset, n$outcome, sep = ".")
    base <- n$main$r2[n$main$model == "none"]
    add_test <- function(km, t) {
      add(paste0(km, ".delta"), fmt_r2(t$delta))
      add(paste0(km, ".deltapct"), fmt_pct(t$delta))
      add(paste0(km, ".relgain"), fmt_pct(t$delta / base))
      add(paste0(km, ".cilo"), fmt_r2(t$ci_lo))
      add(paste0(km, ".cihi"), fmt_r2(t$ci_hi))
      add(paste0(km, ".t"), fmt_num(t$t, 2))
      add(paste0(km, ".df"), as.character(t$df))
      add(paste0(km, ".p"), fmt_p(t$p))
    }
    for (i in seq_len(nrow(n$main))) {
      m  <- n$main[i, ]
      km <- paste(k, key_model(m$model), sep = ".")
      add(paste0(km, ".r2"), fmt_r2(m$r2))
      add(paste0(km, ".alpha"), fmt_num(m$alpha_median, 1))
      add(paste0(km, ".lambda"), fmt_sig(m$lambda_median))
      ## outer folds without R^2 (constant predictions); r2 is the mean of the others
      add(paste0(km, ".nna"), as.character(m$n_na))
    }
    for (i in seq_len(nrow(n$tests))) {
      t  <- n$tests[i, ]
      km <- paste(k, key_model(t$model), sep = ".")
      add_test(km, t)
      add(paste0(km, ".mcse"), fmt_sig(t$mcse, 2))
    }
    for (sel in c("confirm", "best")) {
      t <- if (sel == "confirm") n$tests[n$tests$model == confirm_model(n), ] else nested_best(n)
      add(paste(k, sel, "model", sep = "."), text_label(strsplit(t$model, "+", fixed = TRUE)[[1]]))
      add(paste(k, sel, "r2", sep = "."), fmt_r2(n$main$r2[n$main$model == t$model]))
      add_test(paste(k, sel, sep = "."), t)
    }
  }
  vals
}

## --- everything ------------------------------------------------------------------------------
## keys of the overlap analysis (overlap.R):
##   <emb>.<dataset>.overlap.<variable>   adjusted R^2 (numeric) or Tjur's R^2
##                                        (binary) of the variable on the text PCs
##   <emb>.<dataset>.overlap.{group,n,nbinary,nrare,nmultilevel}
##   <emb>.<dataset>.<outcome>.textsignal.r2   adjusted R^2 of the text-only
##                                        predictions on the other predictors
build_overlap_results <- function() {
  vals <- list()
  add <- function(key, value) vals[[gsub("_", "-", tolower(key))]] <<- value
  add("set.overlap.minperpc", as.character(OVERLAP_MIN_PER_PC))
  add("set.overlap.minn", as.character(OVERLAP_MIN_PER_PC * NPRIN))
  for (emb in names(EMBEDDING_MODELS)) {
    o <- readRDS(overlap_file(emb))
    for (ds in unique(o$variables$dataset)) {
      v  <- o$variables[o$variables$dataset == ds, ]
      kd <- paste(emb, ds, "overlap", sep = ".")
      add(paste0(kd, ".group"), text_label(v$group[1]))
      add(paste0(kd, ".n"), fmt_int(v$n[1]))
      add(paste0(kd, ".nbinary"), as.character(sum(v$type == "binary")))
      add(paste0(kd, ".nrare"), as.character(sum(v$type == "binary_rare")))
      add(paste0(kd, ".nmultilevel"), as.character(sum(v$type == "multilevel")))
      for (i in which(!is.na(v$r2))) add(paste(kd, v$variable[i], sep = "."), fmt_r2(v$r2[i]))
    }
    s <- o$text_signal
    for (i in seq_len(nrow(s))) {
      add(paste(emb, s$dataset[i], s$outcome[i], "textsignal.r2", sep = "."), fmt_r2(s$adj_r2[i]))
    }
  }
  vals
}

export_all <- function() {
  dir.create(GENERATED_DIR, showWarnings = FALSE)
  res  <- load_results()
  nres <- load_nested()   # NULL until the nested CV has run for every analysis
  if (is.null(nres)) {
    warning("nested CV results missing: the main results keys and Tables 1 and ",
            "tab_models are not written (run with RUN_NESTED <- TRUE)")
  }
  write_results_tex(c(build_results(res), build_overlap_results(),
                      if (!is.null(nres)) build_nested_results(nres)),
                    file.path(GENERATED_DIR, "results.tex"))
  for (emb in names(EMBEDDING_MODELS)) {
    if (!is.null(nres)) {
      write_summary_table(res, nres, emb, file.path(GENERATED_DIR, paste0("tab_summary_", emb, ".tex")))
    }
    write_overlap_table(emb, file.path(GENERATED_DIR, paste0("tab_overlap_", emb, ".tex")))
  }
  for (key in names(res)) {
    r    <- res[[key]]
    stem <- paste(r$embedding, r$dataset, r$outcome, sep = "_")
    if (!is.null(nres)) {
      write_models_table(r, nres[[key]], file.path(GENERATED_DIR, paste0("tab_models_", stem, ".tex")))
    }
    write_examples_rows(r, file.path(GENERATED_DIR, paste0("tab_examples_", stem, ".tex")))
  }
  ## last, so that a missing translation stops the export after everything else is written
  write_translated_examples(res)
  invisible(TRUE)
}
