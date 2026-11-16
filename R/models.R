## ---------------------------------------------------------------------------
## models.R
##
## Cross-validated elastic net models for one analysis (embedding model x
## dataset x outcome).
##
## Models: the baseline (non-text predictors only), the baseline extended by
## every non-empty combination of the dataset's free-text responses, and a
## text-only model with all free-text responses. Each model with text is fit
## for every nprin in the sweep grid; the main analysis is nprin = NPRIN.
## All models of one outcome share the same participants and the same folds.
##
## The text PCs are computed within each CV fold: the PCA of each free-text
## response is fit on the training rows only, and the held-out rows are
## projected onto those components (fold_pca_glmnet).
## ---------------------------------------------------------------------------

library(caret)
library(glmnet)

## all model specifications for a set of text groups
model_specs <- function(groups) {
  combos <- unlist(lapply(0:length(groups), function(k) {
    combn(groups, k, simplify = FALSE)
  }), recursive = FALSE)
  specs <- lapply(combos, function(g) {
    list(id = if (length(g)) paste(g, collapse = "+") else "none",
         other = TRUE, groups = g)
  })
  c(specs, list(list(id = "text_only", other = FALSE, groups = groups)))
}

## text groups enter with their embedding columns; fold_pca_glmnet turns
## these into the first np PCs within each fold
model_formula <- function(spec, outcome, predictors, data_names) {
  rhs <- c(if (spec$other) predictors,
           unlist(lapply(spec$groups, emb_cols, names = data_names)))
  reformulate(rhs, response = outcome)
}

## caret's glmnet model with a fold-wise PCA in front: fit() runs the PCA of
## each text group on the (training) rows it is given and replaces that
## group's embedding columns by the first np PC scores; predict() projects
## new rows onto the stored training components. caret's center/scale
## preprocessing is applied before, with training-fold statistics.
## The PCAs depend only on the training rows, not on alpha, lambda, np or the
## model, so they are kept in `cache` (an environment shared by all fits of
## one analysis).
fold_pca_glmnet <- function(groups, np, cache) {
  base <- getModelInfo("glmnet", regex = FALSE)$glmnet

  fit_pca <- function(x, g) {
    cols <- emb_cols(colnames(x), g)
    key  <- paste(g, digest::digest(x[, cols], algo = "xxhash64"))
    if (is.null(cache[[key]])) {
      p <- prcomp(x[, cols], scale. = TRUE, rank. = N_PCS_MAX)
      cache[[key]] <- list(cols = cols, center = p$center, scale = p$scale,
                           rotation = p$rotation)
    }
    p <- cache[[key]]
    stopifnot(np <= ncol(p$rotation))
    p$rotation <- p$rotation[, seq_len(np), drop = FALSE]
    p
  }

  to_pcs <- function(x, pcas) {
    x <- as.matrix(x)
    emb <- unlist(lapply(pcas, `[[`, "cols"))
    pcs <- lapply(names(pcas), function(g) {
      p <- pcas[[g]]
      s <- scale(x[, p$cols, drop = FALSE], p$center, p$scale) %*% p$rotation
      colnames(s) <- pc_names(g, np)
      s
    })
    cbind(x[, setdiff(colnames(x), emb), drop = FALSE], do.call(cbind, pcs))
  }

  m <- base
  m$label <- "glmnet on fold-wise text PCs"
  m$fit <- function(x, y, wts, param, lev, last, classProbs, ...) {
    x    <- as.matrix(x)
    pcas <- setNames(lapply(groups, function(g) fit_pca(x, g)), groups)
    out  <- base$fit(to_pcs(x, pcas), y, wts, param, lev, last, classProbs, ...)
    out$text_pcas <- pcas
    out
  }
  m$predict <- function(modelFit, newdata, submodels = NULL) {
    base$predict(modelFit, to_pcs(newdata, modelFit$text_pcas), submodels)
  }
  m
}

fit_glmnet_cv <- function(formula, data, folds, method = "glmnet") {
  train(
    formula,
    data       = data,
    method     = method,
    trControl  = trainControl(method = "cv", index = folds,
                              savePredictions = "final"),
    tuneGrid   = TUNE_GRID,
    metric     = "Rsquared",
    preProcess = c("center", "scale")
  )
}

## best cross-validated R^2 with its hyperparameters, and the held-out
## predictions of that best setting (ordered by participant)
summarise_fit <- function(fit) {
  res  <- fit$results[!is.na(fit$results$Rsquared), ]
  best <- res[which.max(res$Rsquared), ]
  pred <- fit$pred[order(fit$pred$rowIndex), c("rowIndex", "obs", "pred")]
  list(r2 = best$Rsquared, alpha = best$alpha, lambda = best$lambda,
       pred = pred)
}

## participants whose held-out prediction improved most when text PCs were
## added (improvement = reduction of the absolute residual; shift = change
## of the predicted value)
example_responses <- function(base, text, texts, n = N_EXAMPLES) {
  comp <- data.frame(
    rowIndex       = base$pred$rowIndex,
    actual         = base$pred$obs,
    pred_no_text   = base$pred$pred,
    pred_with_text = text$pred$pred
  )
  stopifnot(identical(base$pred$rowIndex, text$pred$rowIndex))
  comp$shift       <- comp$pred_with_text - comp$pred_no_text
  comp$improvement <- abs(comp$actual - comp$pred_no_text) -
                      abs(comp$actual - comp$pred_with_text)
  top <- comp[order(-comp$improvement), ][seq_len(n), ]
  data.frame(response    = strip_prefix(texts[top$rowIndex]),
             improvement = top$improvement,
             shift       = top$shift,
             stringsAsFactors = FALSE)
}

## everything one analysis needs, without fitting: used for the cache check
analysis_inputs <- function(emb, dataset, outcome_label) {
  prep    <- prepare_dataset(emb, dataset)
  outcome <- prep$outcomes[[outcome_label]]
  smp     <- prep$make_sample(outcome)
  set.seed(SEED)
  folds <- createFolds(smp$data[[outcome]], k = N_FOLDS, returnTrain = TRUE)
  list(prep = prep, outcome = outcome, sample = smp, folds = folds,
       specs = model_specs(prep$groups), nprin_grid = NPRIN_GRID[[dataset]])
}

inputs_key <- function(inp) {
  d    <- inp$sample$data
  used <- c(inp$outcome, all.vars(reformulate(inp$sample$predictors)),
            unlist(lapply(inp$prep$groups, emb_cols, names = names(d))))
  list(data = d[, unique(used)],
       predictors = inp$sample$predictors, folds = inp$folds,
       specs = inp$specs, nprin_grid = inp$nprin_grid,
       grid = TUNE_GRID, nprin = NPRIN, n_examples = N_EXAMPLES,
       pca = "within folds")
}

## version: serialization format. The default (3) writes ALTREP vectors in
## their internal representation, which can change within a session once a
## vector has been used, so the same data can hash differently; version 2
## writes plain values. inputs_hash keeps the default so existing cache
## files stay valid.
hash_object <- function(x, version = NULL) {
  f <- tempfile()
  saveRDS(x, f, compress = FALSE, version = version)
  on.exit(unlink(f))
  unname(tools::md5sum(f))
}

inputs_hash <- function(inp) hash_object(inputs_key(inp))

result_file <- function(emb, dataset, outcome_label) {
  file.path(RESULTS_DIR, paste0("fits_", emb, "_", dataset, "_", outcome_label, ".rds"))
}

run_analysis <- function(emb, dataset, outcome_label) {
  out_file <- result_file(emb, dataset, outcome_label)
  inp  <- analysis_inputs(emb, dataset, outcome_label)
  hash <- inputs_hash(inp)
  if (!FORCE_RERUN && file.exists(out_file) && identical(readRDS(out_file)$hash, hash)) {
    message("up to date: ", out_file)
    return(invisible(out_file))
  }
  message("fitting: ", out_file)

  d     <- inp$sample$data
  y     <- inp$outcome
  preds <- inp$sample$predictors
  pca_cache <- new.env()
  fit   <- function(spec, np) {
    method <- if (length(spec$groups)) fold_pca_glmnet(spec$groups, np, pca_cache) else "glmnet"
    summarise_fit(fit_glmnet_cv(model_formula(spec, y, preds, names(d)), d,
                                inp$folds, method))
  }

  baseline  <- fit(inp$specs[[1]], np = 0)
  sweep     <- list()
  main_fits <- list(none = baseline)
  for (np in inp$nprin_grid) {
    for (spec in inp$specs[-1]) {
      f <- fit(spec, np)
      sweep[[length(sweep) + 1]] <- data.frame(
        nprin = np, model = spec$id, r2 = f$r2, alpha = f$alpha, lambda = f$lambda)
      if (np == NPRIN) main_fits[[spec$id]] <- f
    }
  }
  sweep <- rbind(
    data.frame(nprin = NA, model = "none", r2 = baseline$r2,
               alpha = baseline$alpha, lambda = baseline$lambda),
    do.call(rbind, sweep)
  )
  sweep$delta <- sweep$r2 - baseline$r2

  ## examples: the best model that adds a single free-text response
  r2_single  <- sapply(inp$prep$groups, function(g) main_fits[[g]]$r2)
  best_group <- inp$prep$groups[which.max(r2_single)]
  examples   <- example_responses(
    baseline, main_fits[[best_group]],
    d[[inp$prep$text_cols[[best_group]]]]
  )

  res <- list(
    embedding = emb, dataset = dataset, outcome = outcome_label,
    hash = hash,
    sweep = sweep,
    main = data.frame(
      model  = names(main_fits),
      r2     = sapply(main_fits, `[[`, "r2"),
      alpha  = sapply(main_fits, `[[`, "alpha"),
      lambda = sapply(main_fits, `[[`, "lambda"),
      row.names = NULL
    ),
    main_predictions = lapply(main_fits, `[[`, "pred"),
    example_group = best_group,
    examples = examples,
    sample = list(flow = c(inp$prep$flow, inp$sample$flow),
                  predictors = preds,
                  predictor_blocks = inp$prep$predictor_blocks,
                  dropped_zero_variance = inp$sample$dropped_zero_variance),
    facts = inp$prep$facts,
    session = list(R = R.version.string,
                   caret = as.character(packageVersion("caret")),
                   glmnet = as.character(packageVersion("glmnet")),
                   date = Sys.time())
  )
  dir.create(RESULTS_DIR, showWarnings = FALSE, recursive = TRUE)
  saveRDS(res, out_file)
  invisible(out_file)
}
