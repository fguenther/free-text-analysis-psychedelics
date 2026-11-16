# 3. Models and evaluation

[← From text to numbers](2-From-text-to-numbers.md) · next: [The synthetic data →](4-The-synthetic-data.md)

## Three kinds of model per outcome

| Model | Predictors |
|---|---|
| **Baseline** | the other predictors only |
| **Baseline + text** | the other predictors plus 20 text components per free-text response |
| **Text only** | the text components only |

In datasets with several responses, there is one *baseline + text* model per
combination of responses (GCMQ: events, health, both; PTSD: seven combinations
of acute, post and treat). The model with **all** responses of a dataset is the
**pre-specified test**; the other combinations are reported descriptively.

All models are **elastic net regressions**: linear regressions with a penalty
that shrinks unhelpful coefficients towards zero. This keeps models with many,
partly correlated predictors from overfitting. Two settings, α (the mix of
ridge and lasso penalty) and λ (its strength), are chosen from the data (see
below).

In the code: [`R/models.R`](../R/models.R) (model fitting, the text-only and
combination models).

## Judging a model on people it has not seen

A model's accuracy is only meaningful on participants it was not trained on.
We use **repeated nested cross-validation** ([`R/nested.R`](../R/nested.R)):

1. **Outer loop.** The participants are split into 10 folds. Each fold is held
   out once; the model is trained on the other 90 %.
2. **Inner loop.** Within those 90 %, a 5-fold cross-validation picks α and λ.
   The model is then refitted on the whole 90 % with these values.
3. **Test.** The model predicts the held-out 10 %. The squared correlation
   between predicted and observed values is that fold's **held-out R²**.
4. **Repeat.** The whole procedure runs 10 times with different random splits:
   100 held-out R² values per model, averaged.

The PCA of the text embeddings (page 2) is part of the training: it is computed
on the training participants and only applied to the held-out ones. The
held-out participants are thus used neither for the coefficients, nor for α
and λ, nor for the PCA.

## Does the text help? ΔR² and its test

**ΔR²** is the held-out R² of *baseline + text* minus that of *baseline*,
computed within each of the 100 outer folds and averaged. Since all models of
an outcome use the same folds, the comparison is paired.

Because the training sets of different folds overlap, the 100 differences are
not independent, and an ordinary *t*-test would be too optimistic. We use the
**corrected repeated *k*-fold *t*-test** (Nadeau & Bengio, 2003; Bouckaert &
Frank, 2004), which inflates the variance accordingly, and report the 95 %
confidence interval from the same corrected standard error.

## Additional analyses

These use one single (non-repeated, non-nested) 10-fold cross-validation run:

* **Number of components (sweeps).** The same models with 2 to 100 text
  components (PTSD: up to 60; Supplementary Material, Figures 2 and 3).
* **Qualitative examples.** For each participant, the held-out prediction of
  the baseline and of the *baseline + text* model are compared. The 15
  responses where adding the text reduced the prediction error the most are
  shown in the example tables, with the *shift* (how much the text moved the
  prediction, and in which direction).
* **Overlap with the other predictors** ([`R/overlap.R`](../R/overlap.R)). How
  much of each other predictor can be predicted from the 20 text components
  (Table 2), and how much of the outcome-relevant text information the other
  predictors already contain (*text signal*). This shows whether the texts
  merely repeat what the questionnaires measure.

All settings (number of folds, repeats, components, the α and λ grids, random
seed) are in [`R/config.R`](../R/config.R).
