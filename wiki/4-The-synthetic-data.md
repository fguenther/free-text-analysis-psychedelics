# 4. The synthetic data

[← Models and evaluation](3-Models-and-evaluation.md) · next: [Reproducing the analysis →](5-Reproducing-the-analysis.md)

## Why synthetic data

The participant data cannot be published: free-text descriptions of personal,
often traumatic experiences can identify people and reveal their psychological
states. To still make the analysis fully reproducible, this repository
contains a **synthetic dataset** with the same structure as the real one. The
code runs on it unchanged, from the raw files to every number in the
manuscript.

**The synthetic data contain no information about any real participant, and
the results obtained from them are not findings.** The article's findings
(`manuscript.pdf`) come from the real data, which are available on request (see
the data availability statement of the article).

## How the synthetic data were made

**Free-text responses.** About 2,900 responses (English and German, in the
same proportions as in the real data) were newly written for this repository
by an AI model (Claude), in the style and on the topics of the real responses
but entirely new: none is copied, paraphrased or assembled from a real
response. Each response is tagged with *theme scores* (e.g. positive affect,
insight, persistent symptoms; [`synthetic/texts/CODEBOOK.md`](../synthetic/texts/CODEBOOK.md)).

**Other variables.** [`synthetic/generate.R`](../synthetic/generate.R) draws
the predictors and outcomes from a statistical model (a Gaussian copula) that
reproduces coarse aggregate statistics of the real data: the distribution of
each variable and the correlations between them. These statistics are
published in [`synthetic/spec_public/`](../synthetic/spec_public/), coarsened so
that no individual can be recognised (only 5–95 % quantiles, small groups
pooled or left out). Sample sizes and file formats are those of the real study.

**A planted signal.** To give the analysis something to find, the outcomes
depend on the theme scores of the synthetic responses, mirroring the
published pattern: the texts carry information about WHO-5, AAQ-II and PCL-5
(PTSD: strongly in the *post* responses, moderately in *treat*, not in
*acute*), and none about WEMWBS and PTGI. A useful check of the pipeline is
whether it finds the signal where it was planted and nothing where there is
none:

| | WHO-5 | AAQ-II | WEMWBS | PCL-5 | PTGI |
|---|---|---|---|---|---|
| ΔR², real data (article) | .041 | .030 | .006 | .097 | −.016 |
| ΔR², synthetic data | .042 | .033 | −.002 | .124 | −.008 |
| signal planted? | yes | yes | no | yes | no |

The synthetic values resemble the real ones by construction; their closeness
says nothing about the real data.

## Privacy checks

Before publication, the synthetic responses were compared with all real
responses (identical texts, shared runs of 10 words, and similarity of their
embeddings); flagged responses were read side by side with the most similar
real response. The result is in [`synthetic/privacy_report.md`](../synthetic/privacy_report.md).
The scripts that needed the real data (`extract_spec.R`, `public_spec.R`,
`check_privacy.R`) are included for transparency but cannot run without it.
