## ---------------------------------------------------------------------------
## embed.R
##
## Extracts sentence embeddings for all free-text responses of one dataset
## with one embedding model, via Python's sentence-transformers (through
## reticulate). The model runs locally; no text leaves the machine.
##
## Result: data/embeddings/<model>_<dataset>.rds, a named list with one entry
## per free-text response type ("text group"):
##   list(<group> = list(text = <embedded strings>,
##                       embedding = <n x 1024 matrix, L2-normalised>))
## plus an attribute "info" recording model and package versions.
##
## Python: py_require() lets reticulate set up a private environment with the
## versions below (checked: they reproduce the embeddings of the analysis to
## ~1e-7, CPU). To use an existing Python environment instead (e.g. if the
## automatic setup fails), point RETICULATE_PYTHON to its python executable
## before starting R; py_require() is then ignored.
## ---------------------------------------------------------------------------

PYTHON_PACKAGES <- c("sentence-transformers==6.0.1", "torch==2.14.0", "transformers==5.14.1")

embedding_file <- function(emb, dataset) {
  file.path(DATA_EMBEDDINGS, paste0(emb, "_", dataset, ".rds"))
}

embed_dataset <- function(emb, dataset) {
  out_file <- embedding_file(emb, dataset)
  texts    <- dataset_texts(dataset)
  ## the cache is reused only if it holds exactly the texts to embed now
  if (file.exists(out_file)) {
    cache <- readRDS(out_file)
    same  <- identical(sort(names(cache)), sort(names(texts))) &&
      all(vapply(names(texts), function(g) identical(cache[[g]]$text, texts[[g]]), logical(1)))
    if (same) return(invisible(out_file))
    message("The texts of ", dataset, " differ from those in ", out_file, ": embedding again.")
  }

  message("Embedding ", dataset, " with ", emb, " (this takes a while) ...")
  library(reticulate)
  py_require(PYTHON_PACKAGES)
  st <- import("sentence_transformers")

  spec  <- EMBEDDING_MODELS[[emb]]
  model <- st$SentenceTransformer(spec$hf_name, revision = spec$revision)
  if (!is.null(spec$max_seq_length)) model$max_seq_length <- spec$max_seq_length
  tokenizer <- model$tokenizer

  result <- lapply(texts, function(x) {
    n_tokens <- vapply(x, function(s) length(tokenizer$encode(s)), integer(1))
    emb_mat  <- py_to_r(model$encode(x, normalize_embeddings = TRUE))
    list(text = x, embedding = emb_mat,
         truncated = sum(n_tokens > model$max_seq_length))
  })

  attr(result, "info") <- list(
    model                 = spec$hf_name,
    revision              = spec$revision,
    max_seq_length        = model$max_seq_length,
    sentence_transformers = st$`__version__`,
    torch                 = import("torch")$`__version__`,
    transformers          = import("transformers")$`__version__`,
    python                = py_config()$version,
    date                  = Sys.Date()
  )
  dir.create(DATA_EMBEDDINGS, showWarnings = FALSE, recursive = TRUE)
  saveRDS(result, out_file)
  invisible(out_file)
}
