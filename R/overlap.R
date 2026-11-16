## ---------------------------------------------------------------------------
## overlap.R
##
## How much the text data and the other (non-text) predictors share. Two
## descriptive measures, computed after the model fits:
##
## 1. Variable level: each other predictor is regressed on the first NPRIN
##    PCs of one free-text response (PCA on the whole analysis sample).
##    Numeric predictors: linear regression, adjusted R^2.
##    Binary predictors: logistic regression, Tjur's R^2 (coefficient of
##    discrimination: mean predicted probability of the "yes" cases minus
##    that of the "no" cases). Binary predictors are only used if both
##    classes have at least OVERLAP_MIN_PER_PC * NPRIN (config.R) participants; rarer
##    ones are dropped. Factors with more than two levels and the language
##    of the response (a property of the text itself) are not used.
##    Sample: the analysis sample of the dataset's first outcome. Free-text
##    response: the one with the best single-response extended model of
##    that outcome (APEQ: the only one).
##
## 2. Block level: the held-out predictions of the text-only model (NPRIN)
##    are regressed on all other predictors (the baseline model's terms);
##    the adjusted R^2 is the share of the outcome-relevant text signal that
##    the other predictors already capture. One value per outcome.
## ---------------------------------------------------------------------------

overlap_file <- function(emb) file.path(RESULTS_DIR, paste0("overlap_", emb, ".rds"))

## Tjur's R^2 of a logistic regression of binary y on the PCs
tjur_r2 <- function(y, pcs) {
  fit <- suppressWarnings(glm(y ~ pcs, family = binomial))
  p   <- fitted(fit)
  mean(p[y == 1]) - mean(p[y == 0])
}

variable_overlap <- function(data, vars, group, np = NPRIN) {
  emb <- as.matrix(data[, emb_cols(names(data), group)])
  pcs <- prcomp(emb, scale. = TRUE, rank. = np)$x
  min_n <- OVERLAP_MIN_PER_PC * np
  rows <- lapply(vars, function(v) {
    x <- data[[v]]
    if (is.numeric(x)) {
      return(data.frame(variable = v, type = "numeric", n_min = NA,
                        r2 = summary(lm(x ~ pcs))$adj.r.squared))
    }
    x <- droplevels(as.factor(x))
    if (nlevels(x) != 2) {
      return(data.frame(variable = v, type = "multilevel", n_min = NA, r2 = NA))
    }
    n_min <- min(table(x))
    if (n_min < min_n) {
      return(data.frame(variable = v, type = "binary_rare", n_min = n_min, r2 = NA))
    }
    data.frame(variable = v, type = "binary", n_min = n_min,
               r2 = tjur_r2(as.integer(x == levels(x)[2]), pcs))
  })
  do.call(rbind, rows)
}

text_signal_overlap <- function(r, inp) {
  d    <- inp$sample$data
  pred <- r$main_predictions$text_only
  d$text_signal <- NA_real_
  d$text_signal[pred$rowIndex] <- pred$pred
  fit <- lm(reformulate(r$sample$predictors, response = "text_signal"), data = d)
  data.frame(embedding = r$embedding, dataset = r$dataset, outcome = r$outcome,
             n = nrow(d), adj_r2 = summary(fit)$adj.r.squared)
}

run_overlap <- function(emb) {
  an <- ANALYSES[ANALYSES$embedding == emb, ]
  variables <- list()
  for (ds in unique(an$dataset)) {
    out <- an$outcome[an$dataset == ds][1]
    r   <- readRDS(result_file(emb, ds, out))
    inp <- analysis_inputs(emb, ds, out)
    d   <- inp$sample$data
    vars <- setdiff(unlist(inp$prep$predictor_blocks, use.names = FALSE),
                    inp$prep$language)
    vars <- intersect(vars, all.vars(reformulate(inp$sample$predictors)))
    v <- variable_overlap(d, vars, r$example_group)
    v$block <- sapply(v$variable, function(x) {
      names(Filter(function(b) x %in% b, inp$prep$predictor_blocks))[1]
    })
    variables[[ds]] <- cbind(dataset = ds, outcome = out, group = r$example_group,
                             n = nrow(d), v)
  }
  signal <- do.call(rbind, lapply(seq_len(nrow(an)), function(i) {
    r <- readRDS(result_file(emb, an$dataset[i], an$outcome[i]))
    text_signal_overlap(r, analysis_inputs(emb, an$dataset[i], an$outcome[i]))
  }))
  res <- list(embedding = emb, variables = do.call(rbind, variables),
              text_signal = signal, min_per_pc = OVERLAP_MIN_PER_PC, nprin = NPRIN)
  saveRDS(res, overlap_file(emb))
  invisible(res)
}
