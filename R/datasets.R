## ---------------------------------------------------------------------------
## datasets.R
##
## Reading and preparing the three datasets (APEQ, GCMQ, PTSD).
##
## For each dataset there are two functions:
##   texts_<dataset>()       the free-text responses exactly as they are
##                           embedded (used by embed.R and by prepare)
##   prepare_<dataset>(emb)  analysis-ready data frame with text embeddings
##                           attached, plus everything needed to set up the
##                           models
##
## The text PCs are not computed here: the PCA is fit within each CV fold
## (see models.R), so that held-out participants never shape the components.
##
## prepare_<dataset>() returns a list with
##   data         one row per participant (embedding dimensions as
##                <group>_E<k>)
##   outcomes     named vector: outcome label -> column name
##   groups       names of the free-text responses ("text groups")
##   text_cols    named vector: group -> column with the displayable text
##   make_sample  function(outcome) -> list(data, predictors, flow): the
##                analysis sample and the non-text predictors for one outcome
##   flow         sample-size bookkeeping for the manuscript
##   facts        other dataset-level numbers reported in the manuscript
## ---------------------------------------------------------------------------

library(dplyr)
library(stringr)
library(haven)

## --- shared helpers ----------------------------------------------------------

## the replacement character left behind by broken latin1/UTF-8 round trips
REPLACEMENT_CHAR <- "�"

language_table <- function(x) {
  tab <- table(x)
  setNames(as.integer(tab), names(tab))
}

## attaches one set of embeddings as columns <group>_E<k>: the embedding for
## the rows in `valid` and NA for all other rows
attach_embedding <- function(data, embedding, group, valid = rep(TRUE, nrow(data))) {
  e <- embedding
  e[!valid, ] <- NA_real_
  colnames(e) <- sprintf("%s_E%04d", group, seq_len(ncol(e)))
  cbind(data, as.data.frame(e))
}

## names of the embedding columns of one text group
emb_cols <- function(names, group) {
  grep(paste0("^", group, "_E[0-9]+$"), names, value = TRUE)
}

## look up the cached embedding of each text: positionally if the texts are
## exactly the embedded ones (PTSD, where empty responses repeat), otherwise
## by exact string match
embeddings_for <- function(texts, cache) {
  if (identical(texts, cache$text)) return(cache$embedding)
  idx <- match(texts, cache$text)
  stopifnot(!anyNA(idx), !anyDuplicated(cache$text))
  cache$embedding[idx, , drop = FALSE]
}

pc_names <- function(group, np) paste0(group, "_PC", seq_len(np))

## displayable text: the embedded text without the model prefix
strip_prefix <- function(x) trimws(substring(x, nchar(TEXT_PREFIX) + 1))


## ===========================================================================
## APEQ (Wolff et al., 2022)
## ===========================================================================

read_apeq_raw <- function() {
  d <- read.csv2(file.path(DATA_RAW, RAW_FILES$APEQ),
                 header = FALSE, comment.char = "#")
  names(d) <- iconv(as.character(unlist(d[1, ])), from = "latin1", to = "UTF-8")
  d <- d[-1, ]
  rownames(d) <- NULL
  d
}

clean_apeq_text <- function(x) {
  x <- iconv(x, from = "latin1", to = "UTF-8")
  x <- str_squish(str_trim(x))
  str_replace_all(x, REPLACEMENT_CHAR, "")
}

## All non-empty responses in the raw file (including participants excluded
## later on) are embedded; the analysis sample is a subset of these.
texts_apeq <- function() {
  x <- clean_apeq_text(read_apeq_raw()$SelectedImpactFreeNennung1)
  x <- x[!is.na(x) & x != ""]
  list(text = paste0(TEXT_PREFIX, x))
}

prepare_apeq <- function(emb) {
  raw <- read_apeq_raw()
  flow <- list(raw = nrow(raw))

  d <- raw[as.numeric(raw$Exclusion) == 0, ]
  flow$after_exclusion          <- nrow(d)
  flow$after_exclusion_language <- language_table(d$Sprache)

  ## numeric variables stored with decimal commas
  comma_vars <- c("Dose", "Strength", "Duration", "Valence",
                  "retrospectiveappraisal", "Mood", "Preparedness",
                  "Factor1_Therapeutic", "Factor2_Escapist", "Factor3_Hedonic",
                  "EBI_Total", "CEQ_Total")
  for (v in comma_vars) d[[v]] <- as.numeric(gsub(",", ".", d[[v]]))
  for (v in c("WHOdiff", "AAQdiff", "Age...Jahre", "APEQ_AVPE", "APEQ_ACPE")) {
    d[[v]] <- as.numeric(d[[v]])
  }

  d$Gender <- recode_factor(as.character(d$Gender),
                            `1` = "Female", `2` = "Male",
                            `3` = "Other", `-9` = "NotSpecified")
  d$PsychedelicUsed <- recode_factor(as.character(d$PsychedelicUsed),
                                     `1` = "LSD", `2` = "Psilocybin",
                                     `3` = "Mescaline", `4` = "Ayahuasca")
  ## CASMIN education, grouped as in Wolff et al. (2022)
  d$Education3 <- factor(case_when(
    d$Education %in% c("1", "2", "3")      ~ "Primary",
    d$Education %in% c("4", "5", "6", "7") ~ "Intermediate",
    d$Education %in% c("8", "9")           ~ "Higher"
  ), levels = c("Primary", "Intermediate", "Higher"))
  d$Sprache <- as.factor(d$Sprache)

  ## free-text response: only participants who gave one are analysed
  d$text_raw <- clean_apeq_text(d$SelectedImpactFreeNennung1)
  d <- d[!is.na(d$text_raw) & d$text_raw != "", ]
  rownames(d) <- NULL
  d$text_text <- paste0(TEXT_PREFIX, d$text_raw)
  flow$with_text          <- nrow(d)
  flow$with_text_language <- language_table(d$Sprache)

  cache <- readRDS(embedding_file(emb, "APEQ"))
  d <- attach_embedding(d, embeddings_for(d$text_text, cache$text), "text")

  ## model terms (order as in the original analysis); the APEQ subscales
  ## enter with their interaction
  predictors <- c(
    "Age...Jahre", "Gender", "PsychedelicUsed", "Education3", "Sprache",
    "Dose", "Strength", "Valence", "Duration", "Mood", "Preparedness",
    "retrospectiveappraisal",
    "Factor1_Therapeutic", "Factor2_Escapist", "Factor3_Hedonic",
    "APEQ_ACPE * APEQ_AVPE", "EBI_Total", "CEQ_Total"
  )

  list(
    data      = d,
    outcomes  = c(WHO = "WHOdiff", AAQ = "AAQdiff"),
    groups    = "text",
    text_cols = c(text = "text_text"),
    language  = "Sprache",
    flow      = flow,
    predictor_blocks = list(
      demographic   = c("Age...Jahre", "Gender", "Education3", "Sprache"),
      setting       = c("PsychedelicUsed", "Dose", "Strength", "Valence",
                        "Duration", "Mood", "Preparedness",
                        "retrospectiveappraisal"),
      questionnaire = c("Factor1_Therapeutic", "Factor2_Escapist",
                        "Factor3_Hedonic", "APEQ_ACPE", "APEQ_AVPE",
                        "EBI_Total", "CEQ_Total")
    ),
    facts = list(cor_who_aaq = cor(d$WHOdiff, d$AAQdiff)),
    make_sample = function(outcome) {
      complete_sample(d, outcome, predictors, "text", "Sprache")
    }
  )
}


## ===========================================================================
## GCMQ (Wolff et al., 2024)
## ===========================================================================

read_gcmq_raw <- function() {
  read.csv2(file.path(DATA_RAW, RAW_FILES$GCMQ),
            header = TRUE, comment.char = "#", fileEncoding = "Latin1")
}

## Two free-text responses. Columns MH05x/MH06 = impact on handling stressful
## events, MH04x/MH07 = impact on mental health (the questionnaire changed
## its item names part-way through data collection).
gcmq_text_frame <- function(dat) {
  collect <- function(pattern) {
    cols <- grep(pattern, names(dat), value = TRUE)
    x <- apply(dat[, cols], 1, paste, collapse = " ")
    x <- str_squish(str_trim(x))
    str_replace_all(x, REPLACEMENT_CHAR, "")
  }
  ev <- collect("MH05x|MH06")
  he <- collect("MH04x|MH07")
  keep <- !is.na(ev) & ev != "" & !is.na(he) & he != ""
  prep <- function(x) gsub("<br>", " ", enc2utf8(paste0(TEXT_PREFIX, x)))
  list(keep = keep, events = prep(ev[keep]), health = prep(he[keep]))
}

texts_gcmq <- function() {
  tf <- gcmq_text_frame(read_gcmq_raw())
  list(events = tf$events, health = tf$health)
}

prepare_gcmq <- function(emb) {
  dat  <- read_gcmq_raw()
  flow <- list(raw = nrow(dat), raw_language = language_table(dat$LANGUAGE))

  ## demographic
  dat$Language   <- as.factor(dat$LANGUAGE)
  dat$Age        <- dat$IC04_01
  dat$Gender     <- as.factor(dat$SD01)
  dat$Education  <- as.factor(dat$CASMIN)
  dat$Diagnosis  <- as.factor(dat$MH02_07)
  dat$Depression <- as.factor(dat$MH02_02)
  dat$Anxiety    <- as.factor(dat$MH02_01)
  dat$Adhd       <- as.factor(dat$MH02_08)
  dat$Ptsd       <- as.factor(dat$MH02_09)
  dat$Addiction  <- as.factor(dat$MH02_04)
  dat$Mania      <- as.factor(dat$MH02_03)
  dat$Psychosis  <- as.factor(dat$MH02_05)
  dat$Other_diag <- as.factor(dat$MH02_06)
  ## setting
  dat$Substance              <- as.factor(dat$SE01)
  dat$Clarity                <- dat$SE02
  dat$Dose                   <- dat$SE05
  dat$Valence                <- dat$SE10
  dat$retrospectiveappraisal <- dat$SE11
  dat$conc_none     <- as.factor(dat$SE13_10)
  dat$conc_cannabis <- as.factor(dat$SE13_02)
  dat$conc_alcohol  <- as.factor(dat$SE13_01)
  dat$conc_entact   <- as.factor(dat$SE13_04)
  dat$conc_disso    <- as.factor(dat$SE13_07)
  dat$conc_stim     <- as.factor(dat$SE13_03)
  dat$conc_benzo    <- as.factor(dat$SE13_06)
  dat$conc_opiat    <- as.factor(dat$SE13_05)
  dat$conc_other    <- as.factor(dat$SE13_09)
  dat$Suitability   <- dat$S204
  for (v in c("SettingTherap", "SettingParty", "SettingNature", "SettingCeremony")) {
    dat[[v]] <- as.factor(dat[[v]])
  }

  ## free-text responses: only participants who gave both are analysed
  tf  <- gcmq_text_frame(dat)
  dat <- dat[tf$keep, ]
  rownames(dat) <- NULL
  dat$text_events <- tf$events
  dat$text_health <- tf$health
  flow$with_text          <- nrow(dat)
  flow$with_text_language <- language_table(dat$Language)

  cache <- readRDS(embedding_file(emb, "GCMQ"))
  dat <- attach_embedding(dat, embeddings_for(dat$text_events, cache$events), "events")
  dat <- attach_embedding(dat, embeddings_for(dat$text_health, cache$health), "health")

  blocks <- list(
    demographic   = c("CumSLE", "Language", "Age", "Gender", "Education",
                      "Diagnosis", "Depression", "Anxiety", "Adhd", "Ptsd",
                      "Addiction", "Mania", "Psychosis", "Other_diag"),
    setting       = c("SettingTherap", "SettingParty", "SettingNature",
                      "SettingCeremony", "Substance", "Clarity", "Dose",
                      "Valence", "retrospectiveappraisal", "conc_none",
                      "conc_cannabis", "conc_alcohol", "conc_entact",
                      "conc_disso", "conc_stim", "conc_benzo", "conc_opiat",
                      "conc_other", "Suitability"),
    ## GCMQ_RE is not used: no scores for a large part of the sample
    questionnaire = c("GCMQ_RA", "GCMQ_PA", "GCMQ_CL", "GCMQ_MA",
                      "Int_Ther", "Int_Hedo", "Int_Esca", "APEQ_AVE",
                      "APEQ_ACE", "ASC_OBE", "EBI", "CEQ")
  )
  predictors <- unlist(blocks, use.names = FALSE)

  list(
    data      = dat,
    outcomes  = c(WEMWBS = "WEMWBS"),
    groups    = c("events", "health"),
    text_cols = c(events = "text_events", health = "text_health"),
    language  = "Language",
    flow      = flow,
    predictor_blocks = blocks,
    facts = list(gcmq_re_missing = sum(is.na(dat$GCMQ_RE))),
    make_sample = function(outcome) {
      complete_sample(dat, outcome, predictors, c("events", "health"), "Language")
    }
  )
}


## ===========================================================================
## PTSD (Evens et al., 2026)
## ===========================================================================

## fix labels that were stored as UTF-8 bytes read as windows-1252
unmojibake <- function(x) {
  if (is.null(x) || !length(x)) return(x)
  y <- suppressWarnings(iconv(x, from = "UTF-8", to = "CP1252"))
  Encoding(y) <- "UTF-8"
  bad <- is.na(y) | is.na(suppressWarnings(iconv(y, "UTF-8", "UTF-8")))
  y[bad] <- x[bad]
  y
}

repair_labels <- function(d) {
  d[] <- lapply(d, function(col) {
    l <- attr(col, "label")
    if (!is.null(l)) attr(col, "label") <- unmojibake(as.character(l))
    vl <- attr(col, "labels")
    if (!is.null(vl) && !is.null(names(vl))) names(attr(col, "labels")) <- unmojibake(names(vl))
    col
  })
  d
}

read_ptsd_raw <- function() {
  d <- read_sav(file.path(DATA_RAW, RAW_FILES$PTSD), encoding = "windows-1252")
  as.data.frame(repair_labels(d))
}

PTSD_TEXT_VARS <- c(acute = "text_acute", post = "text_postacute", treat = "text_treat")

## All responses are embedded, including empty ones; empty responses are set
## to missing afterwards (see prepare_ptsd).
texts_ptsd <- function() {
  raw <- read_ptsd_raw()
  lapply(PTSD_TEXT_VARS, function(v) paste0(TEXT_PREFIX, raw[[v]]))
}

prepare_ptsd <- function(emb) {
  d <- read_ptsd_raw()
  flow <- list(raw = nrow(d), raw_language = language_table(d$LANGUAGE))

  cache  <- readRDS(embedding_file(emb, "PTSD"))
  groups <- names(PTSD_TEXT_VARS)
  for (g in groups) {
    ## read the raw response first: for "acute" and "treat" the raw column
    ## has the same name as the prefixed text column created below
    raw   <- d[[PTSD_TEXT_VARS[[g]]]]
    empty <- is.na(raw) | raw == ""
    d[[paste0("text_", g)]] <- paste0(TEXT_PREFIX, raw)
    flow[[paste0("empty_", g)]] <- sum(empty)
    ## The original analysis only treated empty "post" responses as missing;
    ## empty "acute"/"treat" responses entered as the bare prefix text.
    treat_as_missing <- if (PTSD_ALL_EMPTY_TEXTS_MISSING) empty else
      if (g == "post") empty else rep(FALSE, nrow(d))
    d <- attach_embedding(d, embeddings_for(d[[paste0("text_", g)]], cache[[g]]), g,
                          valid = !treat_as_missing)
  }

  ## subs_DOM / subs_DOI: nobody reported these substances
  subs_vars  <- setdiff(grep("^subs_", names(d), value = TRUE),
                        c("subs_other_text", "subs_DOM", "subs_DOI"))
  subs_count_vars  <- subs_vars[grepl("count", subs_vars)]
  subs_factor_vars <- setdiff(subs_vars, subs_count_vars)

  blocks <- list(
    demographic   = c("Language", "Gender", "Age", "Country", "Edu"),
    setting       = c(subs_count_vars, subs_factor_vars, "dose_exp",
                      "clear_exp", "duration_exp", "valence",
                      "evaluation_exp", "challenge"),
    questionnaire = c("ceq_mean", "apeq_ACE_mean", "apeq_AVE_mean",
                      "motive_hedonic", "motive_selfexploration", "motive_escapist")
  )

  list(
    data      = d,
    outcomes  = c(PCL = "pcl_sum", PTGI = "ptgi_sum"),
    groups    = groups,
    text_cols = setNames(paste0("text_", groups), groups),
    language  = "Language",
    flow      = flow,
    predictor_blocks = blocks,
    facts = list(),
    make_sample = function(outcome) {
      ds <- d[!is.na(d[[outcome]]), ]
      ## factor levels are set within the participants with this outcome
      ds$Language <- as.factor(ds$LANGUAGE)
      ds$Gender   <- as.factor(ds$gender)
      ds$Age      <- ds$age
      for (v in subs_count_vars)  ds[[v]] <- as.integer(ds[[v]])
      for (v in subs_factor_vars) ds[[v]] <- as.factor(ds[[v]])
      ds$dose_exp       <- as.numeric(ds$dose_exp)
      ds$clear_exp      <- as.numeric(ds$clear_exp)
      ds$duration_exp   <- as.numeric(ds$duration_exp)
      ds$valence        <- as.numeric(ds$acute_exp)
      ds$evaluation_exp <- as.numeric(ds$evaluation_exp)
      ds$challenge      <- as.numeric(ds$challenge_exp)
      ## use motives: factor scores of the 22 "set_*" intention items, computed
      ## in the original study (SPSS regression scores, all 243 participants)
      ds$motive_hedonic         <- as.numeric(ds$FAC1_1)
      ds$motive_selfexploration <- as.numeric(ds$FAC2_1)
      ds$motive_escapist        <- as.numeric(ds$FAC3_1)
      ## rare countries / education levels (<= 5 participants among those
      ## with the outcome) are pooled into one "other" category (999).
      ## Counted before complete_sample() drops rows with missing data, so
      ## a level can have <= 5 participants in the analysed sample (PCL:
      ## one country with 6 participants with the outcome, 5 analysed).
      pool_rare <- function(x) {
        tab <- table(x)
        x[x %in% names(tab)[tab <= 5]] <- 999
        as.factor(x)
      }
      ds$Edu     <- pool_rare(ds$edu)
      ds$Country <- pool_rare(ds$country)
      complete_sample(ds, outcome, unlist(blocks, use.names = FALSE), groups,
                      "Language", n_with_outcome = nrow(ds))
    }
  )
}


## ===========================================================================
## shared: analysis sample for one outcome
## ===========================================================================

## Restricts to participants with complete data on the outcome, all non-text
## predictors and ALL free-text responses of the dataset, so that every model
## of one outcome (with or without text, at every nprin) is fit on the same
## rows.
complete_sample <- function(d, outcome, predictors, groups, language,
                            n_with_outcome = sum(!is.na(d[[outcome]]))) {
  text_vars <- unlist(lapply(groups, emb_cols, names = names(d)))
  vars <- unique(c(outcome, all.vars(reformulate(predictors)), text_vars))
  ## participants with the outcome who are not analysed: first those with a
  ## missing (empty) free-text response, then, among the rest, those with a
  ## missing other predictor
  has_outcome <- !is.na(d[[outcome]])
  text_ok     <- complete.cases(d[, text_vars, drop = FALSE])
  pred_ok     <- complete.cases(d[, setdiff(vars, c(outcome, text_vars)), drop = FALSE])
  ds <- d[complete.cases(d[, vars]), ]
  rownames(ds) <- NULL

  ## factors that are constant in this sample cannot enter a model
  zero_var <- Filter(function(v) is.factor(ds[[v]]) && nlevels(droplevels(ds[[v]])) < 2,
                     all.vars(reformulate(predictors)))
  predictors <- setdiff(predictors, zero_var)

  list(
    data       = ds,
    predictors = predictors,
    dropped_zero_variance = zero_var,
    flow = list(with_outcome = n_with_outcome,
                excluded_text      = sum(has_outcome & !text_ok),
                excluded_predictor = sum(has_outcome & text_ok & !pred_ok),
                analysed     = nrow(ds),
                analysed_language = language_table(ds[[language]]))
  )
}

prepare_dataset <- function(emb, dataset) {
  switch(dataset,
         APEQ = prepare_apeq(emb),
         GCMQ = prepare_gcmq(emb),
         PTSD = prepare_ptsd(emb))
}

dataset_texts <- function(dataset) {
  switch(dataset,
         APEQ = texts_apeq(),
         GCMQ = texts_gcmq(),
         PTSD = texts_ptsd())
}
