## ---------------------------------------------------------------------------
## run_all.R
##
## Runs the complete analysis and writes everything the manuscript reads
## into tex/generated/. Run from the repository root:
##
##   Rscript run_all.R        (or source("run_all.R") in R/RStudio)
##
## Steps (expensive steps are cached, see R/config.R):
##   1. text embeddings        data/embeddings/   (only if missing)
##   2. model fits + sweeps    results/           (only if inputs changed)
##  2b. repeated nested CV     results/nested/    (only if inputs changed; long)
##   3. overlap analysis       results/overlap_<emb>.rds
##   4. figures, tables, numbers  tex/generated/
## ---------------------------------------------------------------------------

## work from the repository root, wherever this script is started from
local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  if (length(f)) setwd(dirname(normalizePath(f)))
})
if (!file.exists("R/config.R")) stop("Run run_all.R from the repository root.")

source_all <- function() {
  for (f in c("config", "embed", "datasets", "models", "nested", "figures", "export_tex", "overlap")) {
    source(file.path("R", paste0(f, ".R")))
  }
}
source_all()

## --- 0. synthetic raw data (public repository only) ---------------------------
## With SYNTHETIC = TRUE (R/config_data.R), missing raw files are generated
## from synthetic/ (seeded, so the same files every time).
if (isTRUE(SYNTHETIC) && !all(file.exists(file.path(DATA_RAW, unlist(RAW_FILES))))) {
  source("synthetic/generate.R")
}

## --- 1. embeddings ------------------------------------------------------------
for (emb in names(EMBEDDING_MODELS)) {
  for (dataset in unique(ANALYSES$dataset)) embed_dataset(emb, dataset)
}

## --- 2. models ------------------------------------------------------------------
jobs <- split(ANALYSES, seq_len(nrow(ANALYSES)))
run_job <- function(job) run_analysis(job$embedding, job$dataset, job$outcome)

if (N_CORES > 1) {
  cl <- parallel::makeCluster(N_CORES)
  parallel::clusterCall(cl, setwd, getwd())
  parallel::clusterExport(cl, "source_all")
  parallel::clusterEvalQ(cl, source_all())
  invisible(parallel::parLapplyLB(cl, jobs, run_job))
  parallel::stopCluster(cl)
} else {
  invisible(lapply(jobs, run_job))
}

## --- 2b. repeated nested CV of the main models (long, see R/config.R) ------------
if (RUN_NESTED) {
  nested_jobs <- merge(ANALYSES, data.frame(rep = seq_len(N_REPEATS)))
  ## PTSD has the most models: start those first so the load balances
  nested_jobs <- nested_jobs[order(nested_jobs$dataset != "PTSD", nested_jobs$rep), ]
  nested_jobs <- split(nested_jobs, seq_len(nrow(nested_jobs)))
  run_nested_job <- function(job) {
    run_nested_repeat(job$embedding, job$dataset, job$outcome, job$rep)
  }
  if (N_CORES_NESTED > 1) {
    cl <- parallel::makeCluster(N_CORES_NESTED)
    parallel::clusterCall(cl, setwd, getwd())
    parallel::clusterExport(cl, "source_all")
    parallel::clusterEvalQ(cl, source_all())
    invisible(parallel::parLapplyLB(cl, nested_jobs, run_nested_job))
    parallel::stopCluster(cl)
  } else {
    invisible(lapply(nested_jobs, run_nested_job))
  }
  for (i in seq_len(nrow(ANALYSES))) {
    collect_nested(ANALYSES$embedding[i], ANALYSES$dataset[i], ANALYSES$outcome[i])
  }
}

## --- 3. overlap of text data and other predictors (descriptive, cheap) ----------
for (emb in names(EMBEDDING_MODELS)) run_overlap(emb)

## --- 4. figures, tables and numbers for the manuscript ----------------------------
dir.create(GENERATED_DIR, showWarnings = FALSE)
for (emb in names(EMBEDDING_MODELS)) make_sweep_figure(emb)
export_all()

writeLines(capture.output(sessionInfo()), file.path(RESULTS_DIR, "session_info.txt"))
message("done.")
