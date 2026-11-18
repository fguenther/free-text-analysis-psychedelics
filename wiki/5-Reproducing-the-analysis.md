# 5. Reproducing the analysis

[← The synthetic data](4-The-synthetic-data.md) · next: [Reading the results →](6-Reading-the-results.md)

## What you need

* **R** (4.4 or later; the results here were produced with 4.6.1). The package
  versions are recorded in [`renv.lock`](../renv.lock); `renv::restore()`
  installs them.
* **Python**, for the text embeddings. Normally R sets it up by itself the
  first time (via *reticulate*). If that fails, create a Python 3.12
  environment with `pip install -r requirements.txt` and tell R where it is by
  setting the environment variable `RETICULATE_PYTHON` to its python
  executable.
* About 5 GB of disk space for the two language models (downloaded once).
* **LaTeX** (pdfLaTeX and biber), only if you want to compile the manuscript.

No GPU is needed; everything runs on an ordinary CPU.

## Running it

From the repository folder:

```
Rscript run_all.R
```

or `source("run_all.R")` in R/RStudio. This runs every step:

| Step | What happens | Output |
|---|---|---|
| 0 | synthetic raw data (skipped, they are included) | `data/raw/` |
| 1 | text embeddings with both language models | `data/embeddings/` |
| 2 | models with a single cross-validation, sweeps, examples | `results/` |
| 3 | repeated nested cross-validation and tests | `results/nested/` |
| 4 | overlap analysis | `results/` |
| 5 | figures, tables and numbers for the manuscript | `tex/generated/` |

Then compile `tex/manuscript_synthetic.tex` with pdfLaTeX, biber, and pdfLaTeX twice,
and `tex/manuscript_synthetic_SI.tex` with pdfLaTeX (twice).

**Runtime.** About three hours on a desktop computer (14 cores), most of it
for the embeddings and the nested cross-validation. To skip the nested
cross-validation for a quick look, set `RUN_NESTED <- FALSE` in `R/config.R`;
the main tables and the numbers based on them are then not written, so the
manuscript cannot be compiled completely.

**Interruptions.** Every step saves its results, so an interrupted run
continues where it stopped. A step is rerun only when its inputs or settings
change.

## Checking that it worked

The repository contains the outputs of a complete run in `tex/generated/`.
After your run, `git diff` (or comparing the files) shows whether you got the
same. A run from scratch in a clean copy of this repository reproduced the
synthetic data and all tables and numbers exactly; only the run date and the
creation dates stored inside some files differed. On other
hardware or operating systems, the last digit of some numbers may differ,
because the language models compute with floating-point numbers.

## Running it on your own data

The pipeline is not tied to this study: [`R/config_data.R`](../R/config_data.R)
says which raw files are read, and [`R/datasets.R`](../R/datasets.R) how they
are turned into predictors, outcomes and texts. Adapting these two files (and
the analysis list in `R/config.R`) is the starting point for applying the same
analysis to another dataset with free-text responses.
