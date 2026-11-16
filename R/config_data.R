## ---------------------------------------------------------------------------
## config_data.R  --  SYNTHETIC data (public repository)
##
## The settings that depend on which data the pipeline runs on. Sourced by
## config.R. This repository runs the pipeline of the study on SYNTHETIC data
## (see synthetic/ and README.md); the original analysis used the same code
## with the participant data, which cannot be published. Every other file of
## the pipeline is identical to the one used for the original analysis.
## ---------------------------------------------------------------------------

## TRUE marks every value the pipeline writes into the manuscript as synthetic
## (purple text in tex/generated/, purple shades in the figures).
SYNTHETIC <- TRUE

## Synthetic raw files, in the formats of the original raw files.
## run_all.R generates them with synthetic/generate.R if they are missing.
DATA_RAW <- "data/raw"

RAW_FILES <- list(
  APEQ = "synthetic_APEQ.csv",
  GCMQ = "synthetic_GCMQ.csv",
  PTSD = "synthetic_PTSD.sav"
)

## example responses left out of a manuscript table for display purposes,
## named "<embedding>/<dataset>/<outcome>" (none for the synthetic data)
EXAMPLES_DROPPED <- list()

## English versions of example tables (tab_examples_<emb>_<dataset>_<outcome>_en.tex):
## German responses are replaced by their translation from TRANSLATIONS_FILE
## (columns dataset, original, translation) and marked with a dagger.
EXAMPLES_TRANSLATED <- c("e5/APEQ/WHO", "e5/APEQ/AAQ", "e5/GCMQ/WEMWBS", "e5/PTSD/PCL")
TRANSLATE_LANGUAGE  <- "ger"
TRANSLATIONS_FILE   <- "translations/example_responses_en.csv"
