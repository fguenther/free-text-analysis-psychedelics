# 2. From text to numbers

[← The study](1-The-study.md) · next: [Models and evaluation →](3-Models-and-evaluation.md)

## Text embeddings

A language model reads a text and represents it internally as a long list of
numbers, a **text embedding**. Texts with similar meaning get similar
embeddings, in any language the model knows. No human coding is involved: the
embedding is extracted directly from the model.

| | Main analysis | Robustness check (Supplementary Material) |
|---|---|---|
| Model | `intfloat/multilingual-e5-large` | `BAAI/bge-m3` |
| Numbers per response | 1,024 | 1,024 |
| Maximum length | 512 tokens (longer responses are cut) | 8,192 tokens |

Both models are open-weight models from Hugging Face. They are downloaded once
and then run **on your own computer**: no text is sent to any online service.
The exact model versions are pinned (`R/config.R`), so everyone gets the same
embeddings. Each response is prefixed with `passage: ` (as the e5 model expects)
and embedded separately; a person with three responses has three embeddings.

In the code: [`R/embed.R`](../R/embed.R). Python's *sentence-transformers*
library does the work and is called from R through *reticulate*. The
embeddings are stored in `data/embeddings/`, so this step runs only once.

## From 1,024 numbers to 20

1,024 predictors per response are far more than a few hundred participants can
support, and many of them carry overlapping information. We therefore
summarise the embeddings of each response type with a **principal component
analysis (PCA)** and keep the first **20 components**. Twenty is held constant
across all analyses; the Supplementary Material shows how the results change
with fewer or more components (the "sweep" figures).

Importantly, the PCA is computed **inside the cross-validation** (next page):
only on the participants used to train a model, never on those it is tested
on.
