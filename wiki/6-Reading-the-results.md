# 6. Reading the results

[← Reproducing the analysis](5-Reproducing-the-analysis.md) · next: [Repository map →](7-Repository-map.md)

## The article and the synthetic manuscript

* [`manuscript.pdf`](../manuscript.pdf) is the article with the results of the
  **real** data.
* [`tex/main_v2_translated.pdf`](../tex/main_v2_translated.pdf) is the **same
  text**, filled with the results of the **synthetic** run of this
  repository. (`tex/main_v2.pdf` is identical except that German example
  responses appear in German.)

Putting the two side by side shows which part of the article each piece of
code produces.

## Colours in the synthetic manuscript

* **Purple**: everything the pipeline produced from the synthetic data: every
  number in the text, all table entries, the example responses and the
  figures.
* **Red**: sentences that do not fit the synthetic results (e.g. a claim about
  a pattern the synthetic data do not show) or that describe the original data
  only (e.g. how participants were recruited).
* Black: text that is the same in both versions.

## How numbers get into the text

No result is typed into the manuscript by hand. The pipeline writes all
numbers to [`tex/generated/results.tex`](../tex/generated/results.tex), and the
manuscript reads them by name, for example

```
\res{e5.apeq.who.text.delta}     →  ΔR² for WHO-5, e5 embeddings
```

Tables and figures are written to `tex/generated/` as complete files and
included in the manuscript. Rerunning the pipeline therefore updates the whole
manuscript at once. The code that writes these files is
[`R/export_tex.R`](../R/export_tex.R) (tables, numbers) and
[`R/figures.R`](../R/figures.R) (figures).

## Where each part of the article comes from

| In the article | Produced by | File in `tex/generated/` |
|---|---|---|
| Table 1 (overview, main results) | nested cross-validation | `tab_summary_e5.tex` |
| Table 2 (overlap with other predictors) | overlap analysis | `tab_overlap_e5.tex` |
| Tables 3, 4, 5, 7 (example responses) | single cross-validation run | `tab_examples_e5_*.tex` (`*_en`: with translations) |
| Table 6 (PTSD models) | nested cross-validation | `tab_models_e5_PTSD_PCL.tex` |
| Numbers in the running text | all steps | `results.tex` |
| Table 8 (bge-m3 results, Supplementary) | nested cross-validation | `tab_summary_bge.tex` |
| Figures 2 and 3 (sweeps, Supplementary) | single cross-validation run | `fig_sweeps_e5.pdf`, `fig_sweeps_bge.pdf` |
