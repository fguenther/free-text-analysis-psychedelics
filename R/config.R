## ---------------------------------------------------------------------------
## config.R
##
## Every setting of the analysis lives here. All paths are relative to the
## repository root (run_all.R sets the working directory there).
## ---------------------------------------------------------------------------

## --- data source -------------------------------------------------------------
## Everything that depends on WHICH data the pipeline runs on (the real
## participant data or the synthetic data of the public repository) is in
## R/config_data.R: DATA_RAW, RAW_FILES, SYNTHETIC and the settings of the
## example tables. Every other file of the pipeline is identical in both.
source("R/config_data.R")

## --- paths -----------------------------------------------------------------
DATA_EMBEDDINGS <- "data/embeddings"   # cache of extracted text embeddings
RESULTS_DIR     <- "results"           # fitted results (derived from raw data)
GENERATED_DIR   <- "tex/generated"     # .tex / .pdf files read by the manuscript (tex/)

## --- text embedding models -------------------------------------------------
## max_seq_length = NULL keeps the model's default (512 tokens for e5).
## revision: the Hugging Face commit of the model weights, so that a later
## update of a model on the Hub cannot silently change the embeddings.
EMBEDDING_MODELS <- list(
  e5  = list(hf_name = "intfloat/multilingual-e5-large", max_seq_length = NULL,
             revision = "3d7cfbdacd47fdda877c5cd8a79fbcc4f2a574f3"),
  bge = list(hf_name = "BAAI/bge-m3",                    max_seq_length = 8192L,
             revision = "5617a9f61b028005a4858fdac845db406aefb181")
)

## The "passage: " prefix (an e5 convention) is applied to every text for BOTH
## models, so the two pipelines differ in the embedding model alone.
TEXT_PREFIX <- "passage: "

## --- analysis --------------------------------------------------------------
SEED      <- 2107   # set before creating the CV folds of every analysis
N_FOLDS   <- 10
NPRIN     <- 20     # number of text PCs per free-text response (main analysis)
N_PCS_MAX <- 200    # PCs kept per (fold-wise) PCA of one text type

## elastic net hyperparameter grid (lambda log-spaced)
TUNE_GRID <- expand.grid(
  alpha  = seq(0, 1, by = 0.1),
  lambda = 10^seq(-4, 1, length = 100)
)

## repeated nested CV of the main models (nested.R): N_REPEATS x N_FOLDS
## outer folds, alpha and lambda tuned with N_INNER_FOLDS inner folds
N_REPEATS     <- 10
N_INNER_FOLDS <- 5

## nprin values of the hyperparameter sweep (Supplementary Material). The PTSD
## sample is much smaller, so its sweep stops at 60.
NPRIN_GRID <- list(
  APEQ = c(2, 5, 10, 15, 18, 20, 22, 25, 30, 40, 60, 100),
  GCMQ = c(2, 5, 10, 15, 18, 20, 22, 25, 30, 40, 60, 100),
  PTSD = c(2, 5, 10, 15, 18, 20, 22, 25, 30, 40, 60)
)

## every analysis = one embedding model x one dataset x one outcome
ANALYSES <- expand.grid(
  embedding = names(EMBEDDING_MODELS),
  outcome   = c("APEQ/WHO", "APEQ/AAQ", "GCMQ/WEMWBS", "PTSD/PCL", "PTSD/PTGI"),
  stringsAsFactors = FALSE
)
ANALYSES$dataset <- sub("/.*", "", ANALYSES$outcome)
ANALYSES$outcome <- sub(".*/", "", ANALYSES$outcome)
ANALYSES <- ANALYSES[, c("embedding", "dataset", "outcome")]

## PTSD data: 5 participants left the "post" response empty, 10 the "treat"
## response. FALSE reproduces the original analysis, in which only empty
## "post" responses were treated as missing (empty "treat" responses entered
## the models as the embedding of the bare prefix "passage: ").
## TRUE treats every empty response as missing.
PTSD_ALL_EMPTY_TEXTS_MISSING <- TRUE

## number of example responses per table
N_EXAMPLES <- 15

## overlap analysis (overlap.R): a binary predictor is only used if both of
## its classes have at least OVERLAP_MIN_PER_PC * NPRIN participants
OVERLAP_MIN_PER_PC <- 10

## --- run control -----------------------------------------------------------
## TRUE: refit everything even if cached results are up to date.
## Embeddings are only recomputed when their cache file is missing or holds
## other texts than the current data (delete data/embeddings/ to force it).
FORCE_RERUN <- FALSE

## number of parallel R processes for the model fits (1 = sequential)
N_CORES <- max(1, min(nrow(ANALYSES), parallel::detectCores() - 2))

## Repeated nested CV (nested.R). 100 jobs (10 analyses x N_REPEATS); one
## job took 4.5 (APEQ), 6.5 (GCMQ) and 9 min (PTSD) in a test run, about 11
## CPU hours in total, so roughly 1-2 h on 14 cores. Each repeat is cached separately in
## NESTED_DIR, so an interrupted run resumes. FALSE skips it; the manuscript
## numbers of the nested CV are then left out of tex/generated/.
RUN_NESTED     <- TRUE
NESTED_DIR     <- file.path(RESULTS_DIR, "nested")
N_CORES_NESTED <- max(1, parallel::detectCores() - 2)
