# 7. Repository map

[← Reading the results](6-Reading-the-results.md) · [Home](Home.md)

## Top level

| Path | Content |
|---|---|
| `manuscript.pdf` | the article (real data) |
| `README.md` | short overview; this wiki is the longer version |
| `run_all.R` | runs the whole pipeline |
| `renv.lock`, `requirements.txt` | R and Python package versions |
| `LICENSE`, `LICENSE-CC-BY-4.0.md` | licences: MIT for code, CC BY 4.0 for the synthetic data, results and documentation; the article and manuscript are not licensed for reuse |
| `wiki/` | this wiki |

## `R/`: the analysis code

The code is identical to the code that produced the article; only
`config_data.R` differs (it points to the synthetic files).

| File | What it does |
|---|---|
| `config.R` | every setting: language models, number of components, folds, repeats, seeds, hyperparameter grids |
| `config_data.R` | which raw data files are read (here: synthetic) |
| `datasets.R` | reads the raw files and prepares outcomes, predictors and texts for each dataset |
| `embed.R` | text embeddings (language models run locally) |
| `models.R` | elastic net models, single cross-validation, sweeps, examples |
| `nested.R` | repeated nested cross-validation, ΔR², confidence intervals and tests |
| `overlap.R` | overlap of the text components with the other predictors |
| `figures.R` | sweep figures |
| `export_tex.R` | tables and numbers for the manuscript |

## Data and synthetic material

| Path | Content |
|---|---|
| `data/raw/` | the synthetic raw data, in the formats of the original files |
| `data/embeddings/` | created by the run (cached text embeddings; not in the repository) |
| `results/` | created by the run (fitted models; not in the repository) |
| `synthetic/texts/` | the synthetic free-text responses with theme scores, and their codebook |
| `synthetic/spec_public/` | coarsened aggregate statistics of the real data (input of the generator) |
| `synthetic/generate.R` | builds the synthetic raw data |
| `synthetic/privacy_report.md` | result of the privacy check |
| `synthetic/extract_spec.R`, `public_spec.R`, `check_privacy.R` | steps run once on the real data (documentation only) |
| `translations/` | English translations of German synthetic example responses |

## `tex/`: the synthetic manuscript

| Path | Content |
|---|---|
| `main_v2_translated.tex` / `.pdf` | synthetic manuscript, German examples translated |
| `main_v2.tex` / `.pdf` | synthetic manuscript, examples in the original language |
| `generated/` | numbers, tables and figures written by the pipeline |
| `lit.bib`, `workflow.pdf` | bibliography, pipeline figure |
