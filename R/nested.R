## ---------------------------------------------------------------------------
## nested.R
##
## Repeated nested cross-validation of the main models (nprin = NPRIN), for
## an unbiased held-out R^2 and a confidence interval / test for Delta R^2.
##
## Outer loop: N_REPEATS x N_FOLDS-fold CV (caret::createMultiFolds). The
## outer test fold is used only for evaluation.
## Inner loop: within each outer training set, N_INNER_FOLDS-fold CV tunes
## alpha and lambda (same grid as the main analysis); the model is then
## refit on the whole outer training set and predicts the outer test fold.
## The text PCA stays within folds at both levels (fold_pca_glmnet).
## All models of one outcome share the outer AND inner folds.
##
## R^2 per outer fold = squared correlation of held-out predictions and
## observations (as caret's Rsquared); the model's R^2 is the mean over all
## N_REPEATS * N_FOLDS outer folds.
##
## Delta R^2 (extended-by-text vs. baseline) is tested with the corrected
## repeated k-fold t-test (Nadeau & Bengio, 2003; Bouckaert & Frank, 2004):
## paired per-fold differences d_j, J = N_REPEATS * N_FOLDS,
##   se = sqrt((1/J + n_test/n_train) * var(d)),  t = mean(d) / se,  df = J - 1.
##
## The sweep over nprin (models.R) is not nested and keeps a single CV run.
##
## One job = one analysis x one repeat; each job has its own cache file in
## NESTED_DIR, so an interrupted run resumes where it stopped.
## ---------------------------------------------------------------------------

## all outer folds of one analysis (training rows), in repeat order
nested_outer_folds <- function(y) {
  set.seed(SEED)
  f <- createMultiFolds(y, k = N_FOLDS, times = N_REPEATS)
  ## names are FoldXX.RepYY; order by repeat, then fold
  rep  <- as.integer(sub(".*\\.Rep", "", names(f)))
  fold <- as.integer(sub("^Fold(\\d+)\\..*", "\\1", names(f)))
  f[order(rep, fold)]
}

nested_rep_file <- function(emb, dataset, outcome_label, rep) {
  file.path(NESTED_DIR, sprintf("nested_%s_%s_%s_rep%02d.rds", emb, dataset, outcome_label, rep))
}
nested_file <- function(emb, dataset, outcome_label) {
  file.path(RESULTS_DIR, paste0("nested_", emb, "_", dataset, "_", outcome_label, ".rds"))
}

## main models only: baseline, every extended model and text-only, at NPRIN
nested_rep_hash <- function(inp, outer, rep) {
  hash_object(list(main = inputs_key(inp), outer = outer, rep = rep,
                   inner_folds = N_INNER_FOLDS, n_repeats = N_REPEATS,
                   method = "nested, no caret preprocessing"),
              version = 2)
}

## one model on one outer fold: tune on the inner folds, refit on the outer
## training set, predict the outer test fold.
## Unlike fit_glmnet_cv, no caret center/scale preprocessing: glmnet
## (standardize = TRUE) and the PCA (scale. = TRUE) are invariant to it, so
## the fits are identical (checked: predictions agree to ~1e-13), and
## skipping it more than halves the time of the text models (caret would
## rescale every embedding column in every inner fold).
fit_outer_fold <- function(spec, inp, train_rows, inner, cache) {
  d      <- inp$sample$data
  y      <- inp$outcome
  method <- if (length(spec$groups)) fold_pca_glmnet(spec$groups, NPRIN, cache) else "glmnet"
  fit <- train(
    model_formula(spec, y, inp$sample$predictors, names(d)),
    data       = d[train_rows, ],
    method     = method,
    trControl  = trainControl(method = "cv", index = inner,
                              savePredictions = "none", returnResamp = "none"),
    tuneGrid   = TUNE_GRID,
    metric     = "Rsquared"
  )
  test <- setdiff(seq_len(nrow(d)), train_rows)
  pred <- as.numeric(predict(fit, newdata = d[test, ]))
  obs  <- d[[y]][test]
  r2   <- if (sd(pred) > 0) cor(pred, obs)^2 else NA_real_   # constant prediction
  list(r2 = r2, alpha = fit$bestTune$alpha, lambda = fit$bestTune$lambda,
       pred = data.frame(rowIndex = test, obs = obs, pred = pred))
}

run_nested_repeat <- function(emb, dataset, outcome_label, rep) {
  out_file <- nested_rep_file(emb, dataset, outcome_label, rep)
  inp   <- analysis_inputs(emb, dataset, outcome_label)
  outer <- nested_outer_folds(inp$sample$data[[inp$outcome]])
  outer <- outer[(rep - 1) * N_FOLDS + seq_len(N_FOLDS)]
  hash  <- nested_rep_hash(inp, outer, rep)
  if (!FORCE_RERUN && file.exists(out_file) && identical(readRDS(out_file)$hash, hash)) {
    message("up to date: ", out_file)
    return(invisible(out_file))
  }
  message("fitting: ", out_file)
  t0 <- Sys.time()

  y <- inp$sample$data[[inp$outcome]]
  folds <- list()
  preds <- list()
  for (j in seq_along(outer)) {
    train_rows <- outer[[j]]
    ## inner folds: the same for every model of this outer fold
    set.seed(SEED + 1000 * rep + j)
    inner <- createFolds(y[train_rows], k = N_INNER_FOLDS, returnTrain = TRUE)
    cache <- new.env()   # fold-wise PCAs of this outer fold only
    for (spec in inp$specs) {
      f <- fit_outer_fold(spec, inp, train_rows, inner, cache)
      folds[[length(folds) + 1]] <- data.frame(
        rep = rep, fold = j, model = spec$id, r2 = f$r2,
        alpha = f$alpha, lambda = f$lambda,
        n_train = length(train_rows), n_test = nrow(f$pred))
      preds[[length(preds) + 1]] <- cbind(rep = rep, fold = j, model = spec$id, f$pred)
    }
    rm(cache)
  }

  dir.create(NESTED_DIR, showWarnings = FALSE, recursive = TRUE)
  saveRDS(list(hash = hash, folds = do.call(rbind, folds),
               predictions = do.call(rbind, preds),
               seconds = as.numeric(difftime(Sys.time(), t0, units = "secs"))),
          out_file)
  invisible(out_file)
}

## corrected repeated k-fold t-test for paired per-fold differences d
corrected_t <- function(d, n_test, n_train, level = 0.95) {
  ok <- !is.na(d)
  d  <- d[ok]
  J  <- length(d)
  se <- sqrt((1 / J + mean(n_test[ok]) / mean(n_train[ok])) * var(d))
  t  <- mean(d) / se
  q  <- qt(1 - (1 - level) / 2, df = J - 1)
  data.frame(delta = mean(d), se = se, t = t, df = J - 1,
             p = 2 * pt(-abs(t), df = J - 1),
             ci_lo = mean(d) - q * se, ci_hi = mean(d) + q * se,
             n_excluded = sum(!ok))
}

## combines the repeats of one analysis; NULL if any repeat is missing
collect_nested <- function(emb, dataset, outcome_label) {
  files <- vapply(seq_len(N_REPEATS), function(r) nested_rep_file(emb, dataset, outcome_label, r),
                  character(1))
  if (!all(file.exists(files))) return(NULL)
  reps  <- lapply(files, readRDS)
  folds <- do.call(rbind, lapply(reps, `[[`, "folds"))

  models <- unique(folds$model)
  main <- do.call(rbind, lapply(models, function(m) {
    x <- folds[folds$model == m, ]
    data.frame(model = m, r2 = mean(x$r2, na.rm = TRUE), r2_sd = sd(x$r2, na.rm = TRUE),
               n_na = sum(is.na(x$r2)),
               alpha_median = median(x$alpha), lambda_median = median(x$lambda))
  }))

  ## Delta R^2 of every extended model against the baseline, paired by fold
  base <- folds[folds$model == "none", c("rep", "fold", "r2")]
  ext  <- setdiff(models, c("none", "text_only"))
  tests <- do.call(rbind, lapply(ext, function(m) {
    x <- merge(folds[folds$model == m, ], base, by = c("rep", "fold"), suffixes = c("", "_base"))
    d <- x$r2 - x$r2_base
    ## Monte Carlo error of the point estimate: spread of the per-repeat means
    per_rep <- tapply(d, x$rep, mean, na.rm = TRUE)
    cbind(model = m, corrected_t(d, x$n_test, x$n_train),
          rep_sd = sd(per_rep), mcse = sd(per_rep) / sqrt(length(per_rep)))
  }))

  res <- list(embedding = emb, dataset = dataset, outcome = outcome_label,
              n_repeats = N_REPEATS, n_folds = N_FOLDS, n_inner_folds = N_INNER_FOLDS,
              main = main, tests = tests, folds = folds,
              predictions = do.call(rbind, lapply(reps, `[[`, "predictions")),
              seconds = sum(vapply(reps, `[[`, numeric(1), "seconds")))
  saveRDS(res, nested_file(emb, dataset, outcome_label))
  res
}
