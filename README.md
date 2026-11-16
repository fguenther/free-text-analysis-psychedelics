# Predictions from free-text responses in clinical studies: reproducible pipeline on synthetic data

[Author note: This README is AI-generated (Claude Code, Opus 5.5). For the AI 
usage statement for the study itself, please see the respective section in the 
manuscript.]

Analysis code for "Improving predictive accuracy for clinical outcomes with LLM
text embeddings for open-ended free-text responses: A case study on reports of
psychedelic experiences". The article, with the results of the real data, is
[`manuscript.pdf`](manuscript.pdf).

**New here?** The [wiki](wiki/Home.md) explains step by step how the analysis
works and how to reproduce it, for readers of the paper.

The participant data of the study cannot be published. This repository therefore
contains the **complete analysis pipeline of the study, running on a synthetic
dataset**: from the raw files and the extraction of the text embeddings to the
numbers, tables and figures of the manuscript. The code in `R/` and `run_all.R`
is the code that produced the published results; only `R/config_data.R`, which
says which data the pipeline runs on, differs.

**Nothing in the results of this repository is a finding.** The synthetic data
were built so that the pipeline has something realistic to work on, with a known,
planted relation between texts and outcomes (see below).

**Author note: IMPORTANT** The data on which we report in the actual manuscript is 
authentic primary data collected from human participants. No synthetic data is 
reported in the actual manuscript. The sole purpose of generating synthetic data
is that it allows us to make all analyses scripts publicly available in a 
useful manner.


## Running it

```
Rscript run_all.R
```

from the repository root, then compile `tex/main_v2.tex` (pdfLaTeX + biber;
`tex/main_v2_translated.tex` is the version with English translations of German
example responses). The steps:

0. `synthetic/generate.R` writes the synthetic raw files to `data/raw/`
   (seeded; also committed, so this step is skipped).
1. Text embeddings with `intfloat/multilingual-e5-large` and `BAAI/bge-m3`
   (pinned model revisions, `R/config.R`), run locally via Python's
   sentence-transformers. The models are downloaded once (a few GB).
2. Cross-validated elastic net models and the sweep over the number of text PCs.
3. Repeated nested cross-validation (10 × 10 outer folds) with the corrected
   repeated k-fold t-test for ΔR². This is the longest step (1–2 h on 14 cores);
   `RUN_NESTED <- FALSE` in `R/config.R` skips it.
4. Overlap of text and other predictors; figures, tables and numbers in
   `tex/generated/`.

Every step is cached, so an interrupted run resumes. `tex/generated/` in this
repository is the output of a complete run, for comparison.

### Requirements

R (≥ 4.4) with caret, glmnet, dplyr, stringr, haven, ggplot2, cowplot,
reticulate and digest. `renv.lock` records the versions used for the results in
this repository (R 4.6.1; `renv::restore()` installs them).

Python is set up by reticulate (`py_require()` in `R/embed.R`, pinned versions).
If that automatic setup fails (it can on Windows, e.g. when antivirus software
locks files during the installation), create a Python 3.12 environment with
`pip install -r requirements.txt` (the same pins) and point `RETICULATE_PYTHON`
to its python executable before starting R.

With these versions, the embeddings of the original data were reproduced to
~1e-7 (CPU). Results on other hardware may differ in the last digits.

## The synthetic data

| Folder | Content |
|---|---|
| `synthetic/texts/` | ~2,900 synthetic free-text responses (English and German), written for this repository in the style of the real ones but entirely new: none is copied from, paraphrased from or assembled out of a real response. Each is tagged with theme scores; `CODEBOOK.md` describes the themes. |
| `synthetic/spec_public/` | aggregate statistics of the original data, coarsened for publication: sample sizes, quantiles 5–95 % of every variable, category shares (cells < 10 pooled), a correlation matrix of normal scores (groups < 20 left out), text-length quantiles 0–95 %. `*.md` are readable versions. |
| `synthetic/generate.R` | builds the raw files from these two inputs |
| `synthetic/extract_spec.R`, `synthetic/public_spec.R`, `synthetic/check_privacy.R` | the steps run once on the original data by the authors (they need the original data and do not run here) |
| `synthetic/privacy_report.md` | result of the check that no synthetic response reproduces a real one |

How `generate.R` builds the data:

* every analysed synthetic participant gets synthetic response(s); the
  sample sizes and language shares are those of the original data;
* the other predictors come from a Gaussian copula with the correlations of the
  original data, mapped onto the original quantiles and category shares, in the
  formats of the original raw files (so `R/datasets.R` reads them unchanged);
* some predictors share information with the texts (e.g. therapeutic use
  motives and responses about therapeutic use);
* the outcomes depend on the predictors as in the original data, plus a
  **planted text signal**: a weighted sum of theme scores of the response(s)
  (`SIGNAL` in `generate.R`). It mirrors the published results: the texts add
  to the prediction of WHO-5 and AAQ-II changes (APEQ) and of PCL-5 (PTSD; the
  "post" response strongly, "treat" moderately, "acute" not at all), and add
  nothing to WEMWBS (GCMQ) and PTGI (PTSD), which serve as null outcomes.

A useful check of the pipeline is therefore whether it recovers the planted
signal where there is one and finds nothing where there is none.

## The manuscripts in this repository

`manuscript.pdf` is the article with the results of the real data.

`tex/main_v2_translated.tex` (and `tex/main_v2.tex`, with German example
responses untranslated) is the same manuscript text, unchanged, filled with the
results of the synthetic run:

* **purple**: every number, table entry, example response and figure produced
  by the pipeline from the synthetic data;
* **red**: sentences that do not fit the synthetic results, or that describe
  the original data only (e.g. the recruitment of the original sample).

`tex/generated/` is written by R only (`R/export_tex.R`); see the comments
there for how the manuscript reads it (`\res{<key>}` prints one number).

## Original data

The original data are not public (participant data). Requests: see the data
availability statement of the article.

## Structure

| Path | Content |
|---|---|
| `manuscript.pdf` | the article (real data) |
| `wiki/` | how the analysis works and how to reproduce it |
| `run_all.R` | runs the whole pipeline |
| `R/config.R` | every setting: models, seeds, grids |
| `R/config_data.R` | which data the pipeline runs on (here: synthetic) |
| `R/datasets.R` | reading and preparing the APEQ, GCMQ and PTSD data |
| `R/embed.R` | text embeddings (sentence-transformers via reticulate, run locally) |
| `R/models.R` | cross-validated elastic net models and nprin sweeps |
| `R/nested.R` | repeated nested CV, CI and test for ΔR² |
| `R/overlap.R` | overlap of the text data with the other predictors |
| `R/figures.R`, `R/export_tex.R` | figures, tables and numbers for the manuscript |
| `synthetic/` | the synthetic data and how they were made |
| `translations/` | English translations of the German synthetic example responses |
| `renv.lock`, `requirements.txt` | R and Python package versions |
| `LICENSE`, `LICENSE-CC-BY-4.0.md` | licences (see below) |
| `tex/` | manuscript, bibliography, pipeline figure, `generated/` |

## Licence

* **Code** (`run_all.R`, `R/`, the R scripts in `synthetic/`): MIT, see `LICENSE`.
* **Synthetic data, texts and results** (`data/raw/`, `synthetic/texts/`,
  `synthetic/spec_public/`, `synthetic/privacy_report.md`, `translations/`,
  `tex/generated/`), this README and the wiki: CC BY 4.0, see `LICENSE-CC-BY-4.0.md`.
* **Article and manuscript** (`manuscript.pdf`, `tex/main_v2*.tex` and PDFs,
  `tex/workflow.pdf`, `tex/lit.bib`):
  not licensed for reuse; all rights remain with the authors.

When using the code or data, please cite the article.
