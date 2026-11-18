# 6. Reading the results

[← Reproducing the analysis](5-Reproducing-the-analysis.md) · next: [Repository map →](7-Repository-map.md)

## The article and the synthetic manuscript

* [`manuscript.pdf`](../manuscript.pdf) and [`manuscript_SI.pdf`](../manuscript_SI.pdf)
  are the article and its Supplementary Information with the results of the
  **real** data.
* [`tex/manuscript_synthetic.pdf`](../tex/manuscript_synthetic.pdf) and
  [`tex/manuscript_synthetic_SI.pdf`](../tex/manuscript_synthetic_SI.pdf) are the **same text**,
  filled with the results of the **synthetic** run of this repository.

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
| Table 2 (sample descriptives) | data preparation | `tab_descriptives.tex` |
| Table 3 (overlap with other predictors) | overlap analysis | `tab_overlap_e5.tex` |
| Tables 4, 5, 6, 8 (example responses) | single cross-validation run | `tab_examples_e5_*.tex` (`*_en`: with translations) |
| Table 7 (PTSD models) | nested cross-validation | `tab_models_e5_PTSD_PCL.tex` |
| Numbers in the running text | all steps | `results.tex` |
| Supplementary Table 1 (bge-m3 results) | nested cross-validation | `tab_summary_bge.tex` |
| Supplementary Figures 1 and 2 (sweeps) | single cross-validation run | `fig_sweeps_e5.pdf`, `fig_sweeps_bge.pdf` |
