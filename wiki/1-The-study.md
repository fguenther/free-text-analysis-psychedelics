# 1. The study

[← Home](Home.md) · next: [From text to numbers →](2-From-text-to-numbers.md)

## The question

Questionnaires often contain open-ended questions ("Please describe your
experience"), but the answers are rarely analysed, because turning free text
into numbers used to require trained human coders. The study asks: **if we let
a language model turn these answers into numbers, do they improve the
prediction of clinically relevant outcomes, beyond all the other information we
have about the participants?**

## Three datasets

All three are existing survey studies on psychedelic experiences. Participants
answered in English or German.

| Dataset | Free-text responses | Outcome(s) | Other predictors | N analysed |
|---|---|---|---|---|
| **APEQ** (Wolff et al., 2022) | 1: a description of the psychedelic experience | change in well-being (**WHO-5**); change in psychological flexibility (**AAQ-II**), both rated retrospectively before vs. after the experience | 20 | 958 |
| **GCMQ** (Wolff et al., 2024) | 2: impact of the experience on handling stressful **events**; impact on mental **health** | current mental well-being (**WEMWBS**) | 45 | 605 |
| **PTSD** (Evens et al., 2026) | 3: the **acute** challenging experience; **post**-acute symptoms or difficulties; **treat**ment attempts | PTSD symptom severity (**PCL-5**); post-traumatic growth (**PTGI**) | 36 | 232 (PCL-5), 229 (PTGI) |

The *other predictors* fall into three groups:

* **demographic**: age, gender, education, language and, depending on the
  dataset, diagnoses, stressful life events or country
* **setting of the experience**: substance, dose, duration, valence,
  retrospective appraisal, clarity of memory and similar
* **questionnaires**: e.g. the Emotional Breakthrough Inventory (EBI), the
  Challenging Experience Questionnaire (CEQ), the APEQ subscales, use motives,
  and in GCMQ the GCMQ subscales

The full lists are in the Method section of the article; in the code they are
defined in [`R/datasets.R`](../R/datasets.R).

## Who is analysed

Each analysis uses the participants who have the outcome, a non-empty response
for every free-text question of the dataset, and no missing value in the other
predictors. All models for one outcome are fitted on exactly the same
participants, so they can be compared directly.
