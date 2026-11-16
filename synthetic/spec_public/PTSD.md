# Public aggregate spec: PTSD

Aggregate statistics only, coarsened for publication by synthetic/public_spec.R (no min/max, no groups < 20 in correlations, no upper 5% of text lengths).

## Sample flow

- raw: 243
- raw_by_language: eng: 148, ger: 95
- empty_text_acute: 0
- empty_text_post: 5
- empty_text_treat: 10
- empty_text_any: 10
- participants_lacking_a_nontext_predictor: 1
- PCL_with_outcome: 243
- PCL_analysed: 232
- PCL_excluded_empty_text_only: 10
- PCL_excluded_missing_predictor_only: 1
- PCL_excluded_both: 0
- PCL_analysed_by_language: eng: 141, ger: 91
- PCL_dropped_zero_variance: none
- PTGI_with_outcome: 230
- PTGI_analysed: 229
- PTGI_excluded_empty_text_only: 0
- PTGI_excluded_missing_predictor_only: 1
- PTGI_excluded_both: 0
- PTGI_analysed_by_language: eng: 138, ger: 91
- PTGI_dropped_zero_variance: none

## Notes on the raw file format

- File `TRAUMA_raw_data.sav` (SPSS .sav, 317 columns), read with `haven::read_sav(encoding = "windows-1252")`, then `repair_labels()` (variable and value labels stored as UTF-8 bytes read as windows-1252); 2 variable labels and 30 value labels of the columns below are changed by that repair.
- The free-text columns are read correctly with windows-1252 (umlauts intact, no mojibake). A generator writing with `haven::write_sav()` (always UTF-8) gets labels that `repair_labels()` repairs, but non-ASCII characters in the text columns would arrive as mojibake: keep synthetic PTSD texts ASCII (e.g. ae/oe/ue/ss) or check the round trip.
- Empty responses are empty strings `""` (no NA) in the text columns; `prepare_ptsd()` treats them as missing (PTSD_ALL_EMPTY_TEXTS_MISSING = TRUE).
- All columns starting with `subs_` are read; `subs_other_text` (free text, mostly empty), `subs_DOM` and `subs_DOI` (constant 0) are dropped by the pipeline, the others are predictors: names containing `count` as integers, the rest as factors.
- Rare countries / education levels (<= 5 participants with the outcome) are pooled by the pipeline into code 999 (`Country`, `Edu`); `country_raw`/`edu_raw` show the raw codes.
- Negative codes (e.g. -9 = Not answered) are values, not NA, if they occur.

## Raw columns

| column | model_variable | class | type | format.spss | display_width | variable_label | n_value_labels | NA_count | empty_strings | non_empty_text |
|---|---|---|---|---|---|---|---|---|---|---|
| LANGUAGE | Language | character | character | A16 |  | Language | 0 | 0 | 0 |  |
| gender | Gender | haven_labelled/vctrs_vctr/double | double | F3.0 |  | Geschlecht | 5 | 0 |  |  |
| age | Age | numeric | double | F40.0 |  | Alter: ... years old | 0 | <10 |  |  |
| country | Country | haven_labelled/vctrs_vctr/double | double | F3.0 |  | Land | 250 | 0 |  |  |
| edu | Edu | haven_labelled/vctrs_vctr/double | double | F3.0 |  | Ausbildungsgrad | 10 | 0 |  |  |
| subs_psy_count | subs_psy_count | numeric | double | F8.2 | 16 | subs_psy_count | 0 | 0 |  |  |
| subs_count_all | subs_count_all | numeric | double | F8.2 | 16 | subs_count_all | 0 | 0 |  |  |
| subs_psy_mix | subs_psy_mix | numeric | double | F8.2 | 14 | subs_psy_mix | 0 | 0 |  |  |
| subs_mix_all | subs_mix_all | numeric | double | F8.2 | 14 | subs_mix_all | 0 | 0 |  |  |
| subs_exp | subs_exp | numeric | double | F8.0 |  | Substanz: Residual option (negative) or number of selected options | 0 | 0 |  |  |
| subs_LSD | subs_LSD | haven_labelled/vctrs_vctr/double | double | F1.0 |  | Substanz: LSD or LSD derivatives (e.g. 1D-LSD) | 2 | 0 |  |  |
| subs_Psilo | subs_Psilo | haven_labelled/vctrs_vctr/double | double | F1.0 |  | Substanz: Psilocybin-containing substances (e.g. Magic Mushrooms, Truffles, etc.) | 2 | 0 |  |  |
| subs_DMT | subs_DMT | haven_labelled/vctrs_vctr/double | double | F1.0 |  | Substanz: DMT | 2 | 0 |  |  |
| subs_Aya | subs_Aya | haven_labelled/vctrs_vctr/double | double | F1.0 |  | Substanz: Ayahuasca | 2 | 0 |  |  |
| subs_Mesc | subs_Mesc | haven_labelled/vctrs_vctr/double | double | F1.0 |  | Substanz: Mescaline | 2 | 0 |  |  |
| subs_5MeO | subs_5MeO | haven_labelled/vctrs_vctr/double | double | F1.0 |  | Substanz: 5-MeO-DMT | 2 | 0 |  |  |
| subs_DOM | (not used) | haven_labelled/vctrs_vctr/double | double | F1.0 |  | Substanz: DOM | 2 | 0 |  |  |
| subs_DOI | (not used) | haven_labelled/vctrs_vctr/double | double | F1.0 |  | Substanz: DOI | 2 | 0 |  |  |
| subs_MDMA | subs_MDMA | haven_labelled/vctrs_vctr/double | double | F1.0 |  | Substanz: MDMA/Ecstasy | 2 | 0 |  |  |
| subs_2CB | subs_2CB | haven_labelled/vctrs_vctr/double | double | F1.0 |  | Substanz: 2C-B | 2 | 0 |  |  |
| subs_Keta | subs_Keta | haven_labelled/vctrs_vctr/double | double | F1.0 |  | Substanz: Ketamine | 2 | 0 |  |  |
| subs_Cannabis | subs_Cannabis | haven_labelled/vctrs_vctr/double | double | F1.0 |  | Substanz: Cannabis | 2 | 0 |  |  |
| subs_na | subs_na | haven_labelled/vctrs_vctr/double | double | F1.0 |  | Substanz: I don´t know | 2 | 0 |  |  |
| subs_Other | subs_Other | haven_labelled/vctrs_vctr/double | double | F1.0 |  | Substanz: Others | 2 | 0 |  |  |
| subs_other_text | (not used) | character | character | A32767 | 10 | Substanz: Others (free text) | 0 | 0 | 227 | 16 |
| subs_others_count | subs_others_count | numeric | double | F8.2 | 19 | subs_others_count | 0 | 0 |  |  |
| subs_psy_one_var | subs_psy_one_var | haven_labelled/vctrs_vctr/double | double | F8.2 | 18 | 1 / 2 / 3 / 4 / 5 / 6 / 7 / 8 / 9 / 10 / 11 / 12 / 13 / 14 / 15 | 15 | 0 |  |  |
| dose_exp | dose_exp | haven_labelled/vctrs_vctr/double | double | F3.0 |  | Dosis | 6 | 0 |  |  |
| clear_exp | clear_exp | haven_labelled/vctrs_vctr/double | double | F3.0 |  | Erinnerung | 6 | 0 |  |  |
| duration_exp | duration_exp | haven_labelled/vctrs_vctr/double | double | F3.0 |  | Dauer Wirkung | 6 | 0 |  |  |
| acute_exp | valence | haven_labelled/vctrs_vctr/double | double | F3.0 |  | Erlebnis Wirkung | 5 | 0 |  |  |
| evaluation_exp | evaluation_exp | haven_labelled/vctrs_vctr/double | double | F3.0 |  | Bewertung | 6 | 0 |  |  |
| challenge_exp | challenge | haven_labelled/vctrs_vctr/double | double | F3.0 |  | Herausforderung | 5 | 0 |  |  |
| FAC1_1 | motive_hedonic | numeric | double | F11.5 | 13 | REGR factor score   1 for analysis 1 | 0 | 0 |  |  |
| FAC2_1 | motive_selfexploration | numeric | double | F11.5 | 13 | REGR factor score   2 for analysis 1 | 0 | 0 |  |  |
| FAC3_1 | motive_escapist | numeric | double | F11.5 | 13 | REGR factor score   3 for analysis 1 | 0 | 0 |  |  |
| ceq_mean | ceq_mean | numeric | double | F8.2 | 10 | mean CEQ | 0 | 0 |  |  |
| apeq_ACE_mean | apeq_ACE_mean | numeric | double | F8.2 | 15 | mean APEQ acceptance-rel exp | 0 | 0 |  |  |
| apeq_AVE_mean | apeq_AVE_mean | numeric | double | F8.2 | 15 | mean APEQ avoidance-rel exp | 0 | 0 |  |  |
| pcl_sum | pcl_sum | numeric | double | F8.2 | 10 | Sum PCL-5 | 0 | 0 |  |  |
| ptgi_sum | ptgi_sum | numeric | double | F8.2 | 10 | Sum PTGI | 0 | 13 |  |  |
| text_acute | text_acute | character | character | A32767 |  | Offene Fallberichte: Akute Erfahrung: [01] | 0 | 0 | 0 | 243 |
| text_postacute | text_postacute | character | character | A32767 |  | Offene Fallberichte: Anhaltende Beschwerden: [01] | 0 | 0 | <10 | 238 |
| text_treat | text_treat | character | character | A32767 |  | Offene Fallberichte: Therapieversuche: [01] | 0 | 0 | 10 | 233 |

## Numeric variables (quantiles q05-q95)

| variable | n | scale | na | quantiles |
|---|---|---|---|---|
| pcl_sum | 232 | 0-80 | 0 | 4 8 13 17 22 25 27 30 34 36 39 42 46 49 53 56 59 62 66 |
| ptgi_sum | 229 | 0-105 | <0.043 (<10) in the PCL sample | 2 7 10 14 21 25 28 32 39 42 50 57 61 67 70 73 81 89 95 |
| Age | 232 |  | <0.041 (<10) | 19 22 24 26 27 28 30 31 34 35 36 39 40 45 48 50 53 60 65 |
| subs_psy_count | 232 |  | 0 | 1 1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 3 3 |
| subs_count_all | 232 |  | 0 | 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 3 3 4 |
| subs_others_count | 232 |  | 0 | 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 1 1 2 |
| dose_exp | 232 | 1-5 | 0 | 2 2 2 2 2 3 3 3 3 3 3 3 3 4 4 4 4 5 5 |
| clear_exp | 232 | 1-5 | 0 | 2 2 3 3 3 3 3 3 4 4 4 4 4 4 4 4 4 5 5 |
| duration_exp | 232 | 1-5 | 0 | 1 2 3 3 3 3 3 4 4 4 4 4 4 4 4 5 5 5 5 |
| valence | 232 | 1-4 | 0 | 2 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 |
| evaluation_exp | 232 | 1-5 | 0 | 1 1 1 1 1 1 2 2 2 2 3 3 3 3 4 4 4 4 5 |
| challenge | 232 | 1-4 | 0 | 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 4 4 4 4 |
| ceq_mean | 232 |  | 0 | 0.17 0.25 0.32 0.37 0.41 0.45 0.49 0.51 0.53 0.55 0.56 0.59 0.63 0.66 0.69 0.72 0.76 0.81 0.85 |
| apeq_ACE_mean | 232 |  | 0 | 0 2.12 5.14 8.33 10.98 13.33 16.38 18.85 23.88 26.46 31.17 33.33 37.39 42.9 48.23 54.82 61.06 72.39 88.28 |
| apeq_AVE_mean | 232 |  | 0 | 18.88 32.62 38.14 42 48.29 51.61 55.83 57.58 61.5 64.83 66.78 69.77 73.9 77.66 80.92 82.22 84.39 87.65 90.63 |
| motive_hedonic | 232 |  | 0 | -1.58 -1.36 -1.17 -1.04 -0.84 -0.65 -0.42 -0.3 -0.15 0 0.09 0.32 0.57 0.74 0.94 1.03 1.14 1.26 1.49 |
| motive_selfexploration | 232 |  | 0 | -1.25 -1.11 -0.98 -0.85 -0.76 -0.66 -0.54 -0.44 -0.33 -0.18 -0.06 0.09 0.22 0.46 0.68 0.84 1.1 1.51 1.82 |
| motive_escapist | 232 |  | 0 | -1.37 -1.17 -0.93 -0.8 -0.68 -0.56 -0.51 -0.4 -0.24 -0.12 -0.03 0.07 0.19 0.4 0.57 0.73 0.97 1.3 2.03 |

## Categorical variables

**Language** (N = 232)

| level | label | n | share |
|---|---|---|---|
| eng |  | 141 | 0.608 |
| ger |  | 91 | 0.392 |

**Gender** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 2 | Male | 133 | 0.573 |
| 1 | Female | 85 | 0.366 |
| other | 2 level(s) with <10 each, pooled | 14 | 0.060 |

**Country** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 83 | Deutschland | 91 | 0.392 |
| 236 | Vereinigte Staaten | 46 | 0.198 |
| 999 |  | 42 | 0.181 |
| 235 | Vereinigtes Königreich | 17 | 0.073 |
| other | 5 level(s) with <10 each, pooled | 36 | 0.155 |

**Edu** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 9 | Postgraduate degree (M.A., Ph.D., M.D., etc) [9] | 80 | 0.345 |
| 8 | Bachelor`s degree [8] | 76 | 0.328 |
| 6 | High school graduate [6] | 35 | 0.151 |
| 7 | Vocational, trade, or business school/Associates degree/College without degree [7] | 25 | 0.108 |
| other | 2 level(s) with <10 each, pooled | 16 | 0.069 |

**subs_psy_mix** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 1 |  | 149 | 0.642 |
| 2 |  | 83 | 0.358 |

**subs_mix_all** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 1 |  | 123 | 0.530 |
| 2 |  | 109 | 0.470 |

**subs_exp** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 1 |  | 149 | 0.642 |
| 2 |  | 58 | 0.250 |
| other | 5 level(s) with <10 each, pooled | 25 | 0.108 |

**subs_LSD** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 1 |  | 126 | 0.543 |
| 2 |  | 106 | 0.457 |

**subs_Psilo** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 1 |  | 160 | 0.690 |
| 2 |  | 72 | 0.310 |

**subs_DMT** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 1 |  | 221 | 0.953 |
| 2 |  | 11 | 0.047 |

**subs_Aya** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 1 |  | 208 | 0.897 |
| 2 |  | 24 | 0.103 |

**subs_Mesc** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 1 |  | >217 | >0.935 |
| 2 |  | <10 | <0.043 |

**subs_5MeO** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 1 |  | >214 | >0.922 |
| 2 |  | <10 | <0.043 |

**subs_MDMA** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 1 |  | 200 | 0.862 |
| 2 |  | 32 | 0.138 |

**subs_2CB** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 1 |  | >213 | >0.918 |
| 2 |  | <10 | <0.043 |

**subs_Keta** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 1 |  | 203 | 0.875 |
| 2 |  | 29 | 0.125 |

**subs_Cannabis** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 1 |  | 175 | 0.754 |
| 2 |  | 57 | 0.246 |

**subs_na** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 1 |  | >220 | >0.948 |
| 2 |  | <10 | <0.043 |

**subs_Other** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 1 |  | 221 | 0.953 |
| 2 |  | 11 | 0.047 |

**subs_psy_one_var** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 15 |  | 83 | 0.358 |
| 1 |  | 50 | 0.216 |
| 2 |  | 44 | 0.190 |
| 4 |  | 19 | 0.082 |
| 11 |  | 11 | 0.047 |
| other | 7 level(s) with <10 each, pooled | 25 | 0.108 |

**country_raw** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 83 | Deutschland | 91 | 0.392 |
| 236 | Vereinigte Staaten | 46 | 0.198 |
| 235 | Vereinigtes Königreich | 17 | 0.073 |
| other | 29 level(s) with <10 each, pooled | 78 | 0.336 |

**edu_raw** (N = 232)

| level | label | n | share |
|---|---|---|---|
| 9 | Postgraduate degree (M.A., Ph.D., M.D., etc) [9] | 80 | 0.345 |
| 8 | Bachelor`s degree [8] | 76 | 0.328 |
| 6 | High school graduate [6] | 35 | 0.151 |
| 7 | Vocational, trade, or business school/Associates degree/College without degree [7] | 25 | 0.108 |
| other | 5 level(s) with <10 each, pooled | 16 | 0.069 |

## Correlation matrix (normal scores)

Analysed PCL sample; correlations with ptgi_sum pairwise over the 229 participants of this sample with a PTGI score

Left out: Gender=other, Country=235, Edu=other, subs_DMT=2, subs_Other=2, subs_psy_one_var=4, subs_psy_one_var=11, subs_Mesc (all dummies have <10 in one class), subs_5MeO (all dummies have <10 in one class), subs_2CB (all dummies have <10 in one class), subs_na (all dummies have <10 in one class)

| variable | pcl_sum | ptgi_sum | Language=ger | Gender=1 | Age | Country=236 | Country=999 | Country=other | Edu=8 | Edu=6 | Edu=7 | subs_psy_count | subs_count_all | subs_others_count | subs_psy_mix=2 | subs_mix_all=2 | subs_exp=2 | subs_exp=other | subs_LSD=2 | subs_Psilo=2 | subs_Aya=2 | subs_MDMA=2 | subs_Keta=2 | subs_Cannabis=2 | subs_psy_one_var=1 | subs_psy_one_var=2 | subs_psy_one_var=other | dose_exp | clear_exp | duration_exp | valence | evaluation_exp | challenge | ceq_mean | apeq_ACE_mean | apeq_AVE_mean | motive_hedonic | motive_selfexploration | motive_escapist |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| pcl_sum | 1.00 | -0.05 | -0.14 | 0.14 | -0.23 | 0.18 | -0.08 | 0.02 | -0.00 | 0.07 | 0.18 | 0.04 | 0.11 | 0.13 | 0.03 | 0.14 | 0.01 | 0.04 | 0.07 | 0.03 | -0.18 | -0.01 | 0.01 | 0.07 | -0.03 | 0.03 | 0.13 | -0.02 | 0.01 | 0.05 | -0.10 | -0.38 | 0.13 | 0.51 | -0.29 | 0.33 | 0.05 | -0.23 | 0.26 |
| ptgi_sum | -0.05 | 1.00 | -0.05 | 0.01 | 0.14 | 0.07 | 0.05 | 0.05 | -0.07 | -0.02 | 0.05 | 0.17 | 0.16 | 0.07 | 0.12 | 0.14 | 0.02 | 0.16 | 0.04 | 0.04 | 0.10 | 0.12 | 0.03 | 0.04 | -0.03 | -0.09 | -0.03 | -0.02 | 0.09 | -0.12 | 0.18 | 0.49 | -0.16 | -0.02 | 0.48 | -0.14 | -0.07 | 0.27 | -0.00 |
| Language=ger | -0.14 | -0.05 | 1.00 | 0.09 | 0.21 | -0.40 | -0.26 | -0.17 | -0.09 | 0.08 | -0.22 | -0.07 | -0.03 | 0.04 | -0.03 | -0.01 | 0.05 | -0.11 | 0.10 | -0.12 | -0.04 | -0.17 | -0.04 | -0.03 | 0.05 | -0.03 | 0.03 | 0.02 | 0.04 | 0.07 | -0.11 | 0.20 | -0.03 | -0.06 | -0.01 | 0.06 | 0.07 | 0.10 | -0.06 |
| Gender=1 | 0.14 | 0.01 | 0.09 | 1.00 | 0.06 | -0.06 | -0.08 | 0.04 | 0.10 | -0.07 | -0.06 | -0.03 | 0.00 | 0.01 | -0.06 | 0.02 | -0.07 | 0.00 | -0.03 | -0.05 | 0.09 | 0.06 | 0.04 | -0.04 | -0.03 | 0.02 | 0.05 | -0.07 | -0.01 | 0.06 | 0.01 | -0.07 | 0.07 | 0.17 | -0.09 | 0.08 | 0.03 | -0.06 | -0.02 |
| Age | -0.23 | 0.14 | 0.21 | 0.06 | 1.00 | -0.08 | -0.11 | -0.00 | -0.10 | -0.20 | -0.08 | -0.08 | -0.13 | -0.11 | -0.08 | -0.13 | -0.05 | -0.06 | -0.13 | 0.00 | 0.08 | 0.07 | -0.02 | -0.16 | -0.01 | 0.03 | 0.01 | -0.19 | 0.05 | -0.19 | -0.03 | 0.22 | 0.06 | -0.26 | 0.14 | -0.28 | -0.26 | -0.02 | -0.34 |
| Country=236 | 0.18 | 0.07 | -0.40 | -0.06 | -0.08 | 1.00 | -0.23 | -0.21 | 0.07 | -0.03 | 0.28 | 0.01 | -0.05 | -0.10 | 0.01 | -0.03 | -0.01 | 0.04 | -0.13 | 0.18 | -0.03 | -0.01 | -0.09 | 0.02 | -0.13 | 0.17 | -0.07 | -0.07 | 0.03 | -0.13 | -0.06 | -0.11 | 0.10 | 0.11 | -0.02 | 0.02 | -0.10 | -0.02 | -0.07 |
| Country=999 | -0.08 | 0.05 | -0.26 | -0.08 | -0.11 | -0.23 | 1.00 | -0.20 | 0.05 | -0.10 | -0.06 | -0.08 | -0.03 | 0.05 | -0.09 | -0.02 | -0.06 | -0.06 | -0.14 | 0.10 | 0.06 | 0.07 | -0.04 | -0.03 | -0.03 | 0.06 | 0.09 | 0.09 | -0.07 | -0.06 | 0.09 | 0.08 | -0.08 | -0.02 | 0.06 | -0.09 | -0.07 | 0.02 | 0.03 |
| Country=other | 0.02 | 0.05 | -0.17 | 0.04 | -0.00 | -0.21 | -0.20 | 1.00 | -0.12 | 0.02 | 0.08 | 0.07 | 0.08 | 0.05 | 0.08 | 0.07 | 0.08 | 0.00 | 0.06 | -0.03 | 0.09 | -0.03 | 0.09 | -0.02 | -0.02 | -0.09 | -0.07 | 0.11 | -0.01 | 0.13 | 0.15 | -0.06 | 0.10 | -0.05 | -0.03 | 0.06 | 0.03 | -0.07 | -0.00 |
| Edu=8 | -0.00 | -0.07 | -0.09 | 0.10 | -0.10 | 0.07 | 0.05 | -0.12 | 1.00 | -0.29 | -0.24 | 0.01 | -0.01 | -0.03 | -0.00 | 0.01 | -0.06 | 0.08 | -0.01 | 0.01 | 0.06 | 0.01 | -0.10 | 0.05 | 0.01 | -0.01 | -0.04 | -0.12 | -0.07 | -0.04 | 0.03 | -0.04 | 0.07 | 0.12 | -0.06 | 0.06 | 0.02 | 0.00 | -0.11 |
| Edu=6 | 0.07 | -0.02 | 0.08 | -0.07 | -0.20 | -0.03 | -0.10 | 0.02 | -0.29 | 1.00 | -0.15 | -0.05 | -0.01 | 0.03 | -0.01 | 0.04 | 0.06 | -0.11 | 0.10 | -0.02 | -0.02 | -0.17 | -0.12 | 0.01 | 0.13 | -0.02 | -0.07 | 0.09 | -0.11 | 0.15 | 0.02 | -0.05 | -0.00 | 0.09 | -0.05 | 0.17 | 0.09 | 0.14 | 0.14 |
| Edu=7 | 0.18 | 0.05 | -0.22 | -0.06 | -0.08 | 0.28 | -0.06 | 0.08 | -0.24 | -0.15 | 1.00 | 0.08 | 0.04 | 0.00 | 0.06 | -0.02 | -0.01 | 0.10 | -0.04 | 0.10 | -0.03 | 0.06 | 0.04 | 0.00 | -0.11 | 0.12 | -0.03 | 0.11 | 0.24 | -0.08 | -0.08 | -0.02 | 0.07 | 0.12 | -0.02 | 0.04 | 0.02 | 0.02 | 0.11 |
| subs_psy_count | 0.04 | 0.17 | -0.07 | -0.03 | -0.08 | 0.01 | -0.08 | 0.07 | 0.01 | -0.05 | 0.08 | 1.00 | 0.85 | 0.30 | 0.91 | 0.72 | 0.49 | 0.73 | 0.35 | 0.09 | -0.06 | 0.50 | 0.34 | 0.57 | -0.36 | -0.33 | -0.24 | 0.07 | 0.06 | 0.07 | 0.16 | -0.02 | -0.20 | 0.03 | 0.14 | 0.02 | 0.22 | 0.04 | 0.30 |
| subs_count_all | 0.11 | 0.16 | -0.03 | 0.00 | -0.13 | -0.05 | -0.03 | 0.08 | -0.01 | -0.01 | 0.04 | 0.85 | 1.00 | 0.70 | 0.77 | 0.88 | 0.40 | 0.64 | 0.32 | 0.02 | -0.06 | 0.45 | 0.35 | 0.52 | -0.29 | -0.35 | -0.13 | 0.05 | 0.04 | 0.06 | 0.10 | -0.03 | -0.22 | 0.08 | 0.09 | 0.04 | 0.29 | -0.02 | 0.37 |
| subs_others_count | 0.13 | 0.07 | 0.04 | 0.01 | -0.11 | -0.10 | 0.05 | 0.05 | -0.03 | 0.03 | 0.00 | 0.30 | 0.70 | 1.00 | 0.22 | 0.55 | 0.01 | 0.32 | 0.13 | -0.07 | -0.02 | 0.20 | 0.26 | 0.23 | -0.07 | -0.17 | 0.04 | 0.01 | -0.00 | -0.00 | -0.02 | -0.01 | -0.18 | 0.11 | 0.01 | 0.01 | 0.23 | -0.08 | 0.33 |
| subs_psy_mix=2 | 0.03 | 0.12 | -0.03 | -0.06 | -0.08 | 0.01 | -0.09 | 0.08 | -0.00 | -0.01 | 0.06 | 0.91 | 0.77 | 0.22 | 1.00 | 0.78 | 0.76 | 0.46 | 0.33 | 0.04 | -0.11 | 0.41 | 0.21 | 0.59 | -0.38 | -0.35 | -0.26 | 0.06 | 0.02 | 0.08 | 0.14 | -0.04 | -0.12 | 0.01 | 0.10 | 0.04 | 0.23 | -0.00 | 0.24 |
| subs_mix_all=2 | 0.14 | 0.14 | -0.01 | 0.02 | -0.13 | -0.03 | -0.02 | 0.07 | 0.01 | 0.04 | -0.02 | 0.72 | 0.88 | 0.55 | 0.78 | 1.00 | 0.60 | 0.37 | 0.26 | -0.03 | -0.09 | 0.35 | 0.17 | 0.52 | -0.30 | -0.37 | -0.10 | 0.03 | -0.00 | 0.08 | 0.09 | -0.06 | -0.10 | 0.10 | 0.04 | 0.09 | 0.28 | -0.06 | 0.26 |
| subs_exp=2 | 0.01 | 0.02 | 0.05 | -0.07 | -0.05 | -0.01 | -0.06 | 0.08 | -0.06 | 0.06 | -0.01 | 0.49 | 0.40 | 0.01 | 0.76 | 0.60 | 1.00 | -0.19 | 0.19 | 0.02 | -0.13 | 0.12 | -0.04 | 0.41 | -0.30 | -0.28 | -0.20 | 0.04 | -0.03 | 0.07 | 0.11 | -0.03 | 0.01 | -0.04 | 0.01 | 0.05 | 0.13 | -0.06 | 0.08 |
| subs_exp=other | 0.04 | 0.16 | -0.11 | 0.00 | -0.06 | 0.04 | -0.06 | 0.00 | 0.08 | -0.11 | 0.10 | 0.73 | 0.64 | 0.32 | 0.46 | 0.37 | -0.19 | 1.00 | 0.24 | 0.04 | 0.02 | 0.47 | 0.37 | 0.35 | -0.18 | -0.17 | -0.12 | 0.04 | 0.08 | 0.03 | 0.07 | -0.01 | -0.19 | 0.07 | 0.13 | -0.01 | 0.17 | 0.07 | 0.25 |
| subs_LSD=2 | 0.07 | 0.04 | 0.10 | -0.03 | -0.13 | -0.13 | -0.14 | 0.06 | -0.01 | 0.10 | -0.04 | 0.35 | 0.32 | 0.13 | 0.33 | 0.26 | 0.19 | 0.24 | 1.00 | -0.37 | -0.28 | 0.06 | -0.01 | 0.16 | 0.56 | -0.44 | -0.32 | -0.06 | -0.04 | 0.44 | 0.04 | -0.08 | -0.09 | 0.04 | -0.04 | 0.09 | 0.31 | 0.02 | 0.11 |
| subs_Psilo=2 | 0.03 | 0.04 | -0.12 | -0.05 | 0.00 | 0.18 | 0.10 | -0.03 | 0.01 | -0.02 | 0.10 | 0.09 | 0.02 | -0.07 | 0.04 | -0.03 | 0.02 | 0.04 | -0.37 | 1.00 | -0.17 | 0.03 | -0.03 | -0.06 | -0.35 | 0.71 | -0.23 | 0.04 | 0.10 | -0.09 | 0.11 | 0.09 | 0.04 | 0.10 | -0.03 | 0.08 | -0.20 | 0.08 | 0.01 |
| subs_Aya=2 | -0.18 | 0.10 | -0.04 | 0.09 | 0.08 | -0.03 | 0.06 | 0.09 | 0.06 | -0.02 | -0.03 | -0.06 | -0.06 | -0.02 | -0.11 | -0.09 | -0.13 | 0.02 | -0.28 | -0.17 | 1.00 | -0.05 | -0.09 | -0.16 | -0.18 | -0.16 | -0.12 | -0.01 | 0.07 | -0.01 | 0.11 | 0.13 | 0.02 | -0.04 | 0.15 | -0.01 | -0.20 | 0.18 | -0.13 |
| subs_MDMA=2 | -0.01 | 0.12 | -0.17 | 0.06 | 0.07 | -0.01 | 0.07 | -0.03 | 0.01 | -0.17 | 0.06 | 0.50 | 0.45 | 0.20 | 0.41 | 0.35 | 0.12 | 0.47 | 0.06 | 0.03 | -0.05 | 1.00 | 0.30 | 0.12 | -0.21 | -0.19 | 0.06 | -0.01 | 0.01 | -0.04 | 0.12 | -0.02 | -0.14 | 0.00 | 0.10 | -0.04 | 0.03 | -0.08 | 0.21 |
| subs_Keta=2 | 0.01 | 0.03 | -0.04 | 0.04 | -0.02 | -0.09 | -0.04 | 0.09 | -0.10 | -0.12 | 0.04 | 0.34 | 0.35 | 0.26 | 0.21 | 0.17 | -0.04 | 0.37 | -0.01 | -0.03 | -0.09 | 0.30 | 1.00 | 0.03 | -0.20 | -0.18 | -0.13 | 0.11 | 0.02 | -0.24 | 0.05 | -0.08 | -0.24 | -0.03 | 0.13 | -0.14 | 0.07 | -0.08 | 0.28 |
| subs_Cannabis=2 | 0.07 | 0.04 | -0.03 | -0.04 | -0.16 | 0.02 | -0.03 | -0.02 | 0.05 | 0.01 | 0.00 | 0.57 | 0.52 | 0.23 | 0.59 | 0.52 | 0.41 | 0.35 | 0.16 | -0.06 | -0.16 | 0.12 | 0.03 | 1.00 | -0.30 | -0.28 | 0.06 | -0.06 | 0.01 | 0.04 | 0.04 | -0.09 | -0.11 | 0.11 | 0.00 | 0.02 | 0.27 | -0.06 | 0.25 |
| subs_psy_one_var=1 | -0.03 | -0.03 | 0.05 | -0.03 | -0.01 | -0.13 | -0.03 | -0.02 | 0.01 | 0.13 | -0.11 | -0.36 | -0.29 | -0.07 | -0.38 | -0.30 | -0.30 | -0.18 | 0.56 | -0.35 | -0.18 | -0.21 | -0.20 | -0.30 | 1.00 | -0.25 | -0.18 | -0.09 | -0.07 | 0.34 | -0.04 | -0.04 | 0.06 | 0.01 | -0.08 | 0.04 | 0.11 | 0.03 | -0.10 |
| subs_psy_one_var=2 | 0.03 | -0.09 | -0.03 | 0.02 | 0.03 | 0.17 | 0.06 | -0.09 | -0.01 | -0.02 | 0.12 | -0.33 | -0.35 | -0.17 | -0.35 | -0.37 | -0.28 | -0.17 | -0.44 | 0.71 | -0.16 | -0.19 | -0.18 | -0.28 | -0.25 | 1.00 | -0.17 | 0.05 | 0.08 | -0.07 | -0.10 | 0.07 | 0.14 | 0.11 | -0.11 | 0.10 | -0.22 | 0.04 | -0.10 |
| subs_psy_one_var=other | 0.13 | -0.03 | 0.03 | 0.05 | 0.01 | -0.07 | 0.09 | -0.07 | -0.04 | -0.07 | -0.03 | -0.24 | -0.13 | 0.04 | -0.26 | -0.10 | -0.20 | -0.12 | -0.32 | -0.23 | -0.12 | 0.06 | -0.13 | 0.06 | -0.18 | -0.17 | 1.00 | -0.05 | -0.05 | -0.26 | -0.04 | -0.00 | -0.08 | -0.04 | -0.06 | -0.06 | -0.02 | -0.13 | -0.00 |
| dose_exp | -0.02 | -0.02 | 0.02 | -0.07 | -0.19 | -0.07 | 0.09 | 0.11 | -0.12 | 0.09 | 0.11 | 0.07 | 0.05 | 0.01 | 0.06 | 0.03 | 0.04 | 0.04 | -0.06 | 0.04 | -0.01 | -0.01 | 0.11 | -0.06 | -0.09 | 0.05 | -0.05 | 1.00 | 0.10 | 0.13 | 0.03 | 0.04 | 0.07 | 0.08 | 0.09 | 0.14 | 0.06 | 0.11 | 0.14 |
| clear_exp | 0.01 | 0.09 | 0.04 | -0.01 | 0.05 | 0.03 | -0.07 | -0.01 | -0.07 | -0.11 | 0.24 | 0.06 | 0.04 | -0.00 | 0.02 | -0.00 | -0.03 | 0.08 | -0.04 | 0.10 | 0.07 | 0.01 | 0.02 | 0.01 | -0.07 | 0.08 | -0.05 | 0.10 | 1.00 | -0.08 | -0.10 | 0.05 | 0.06 | 0.05 | 0.03 | 0.03 | -0.08 | 0.04 | 0.03 |
| duration_exp | 0.05 | -0.12 | 0.07 | 0.06 | -0.19 | -0.13 | -0.06 | 0.13 | -0.04 | 0.15 | -0.08 | 0.07 | 0.06 | -0.00 | 0.08 | 0.08 | 0.07 | 0.03 | 0.44 | -0.09 | -0.01 | -0.04 | -0.24 | 0.04 | 0.34 | -0.07 | -0.26 | 0.13 | -0.08 | 1.00 | 0.10 | -0.10 | 0.06 | 0.15 | -0.09 | 0.19 | 0.12 | 0.06 | 0.02 |
| valence | -0.10 | 0.18 | -0.11 | 0.01 | -0.03 | -0.06 | 0.09 | 0.15 | 0.03 | 0.02 | -0.08 | 0.16 | 0.10 | -0.02 | 0.14 | 0.09 | 0.11 | 0.07 | 0.04 | 0.11 | 0.11 | 0.12 | 0.05 | 0.04 | -0.04 | -0.10 | -0.04 | 0.03 | -0.10 | 0.10 | 1.00 | 0.19 | -0.21 | -0.08 | 0.29 | -0.00 | -0.15 | 0.09 | 0.11 |
| evaluation_exp | -0.38 | 0.49 | 0.20 | -0.07 | 0.22 | -0.11 | 0.08 | -0.06 | -0.04 | -0.05 | -0.02 | -0.02 | -0.03 | -0.01 | -0.04 | -0.06 | -0.03 | -0.01 | -0.08 | 0.09 | 0.13 | -0.02 | -0.08 | -0.09 | -0.04 | 0.07 | -0.00 | 0.04 | 0.05 | -0.10 | 0.19 | 1.00 | -0.29 | -0.32 | 0.61 | -0.36 | -0.22 | 0.32 | -0.14 |
| challenge | 0.13 | -0.16 | -0.03 | 0.07 | 0.06 | 0.10 | -0.08 | 0.10 | 0.07 | -0.00 | 0.07 | -0.20 | -0.22 | -0.18 | -0.12 | -0.10 | 0.01 | -0.19 | -0.09 | 0.04 | 0.02 | -0.14 | -0.24 | -0.11 | 0.06 | 0.14 | -0.08 | 0.07 | 0.06 | 0.06 | -0.21 | -0.29 | 1.00 | 0.34 | -0.29 | 0.37 | 0.08 | -0.09 | -0.13 |
| ceq_mean | 0.51 | -0.02 | -0.06 | 0.17 | -0.26 | 0.11 | -0.02 | -0.05 | 0.12 | 0.09 | 0.12 | 0.03 | 0.08 | 0.11 | 0.01 | 0.10 | -0.04 | 0.07 | 0.04 | 0.10 | -0.04 | 0.00 | -0.03 | 0.11 | 0.01 | 0.11 | -0.04 | 0.08 | 0.05 | 0.15 | -0.08 | -0.32 | 0.34 | 1.00 | -0.24 | 0.58 | 0.13 | -0.01 | 0.27 |
| apeq_ACE_mean | -0.29 | 0.48 | -0.01 | -0.09 | 0.14 | -0.02 | 0.06 | -0.03 | -0.06 | -0.05 | -0.02 | 0.14 | 0.09 | 0.01 | 0.10 | 0.04 | 0.01 | 0.13 | -0.04 | -0.03 | 0.15 | 0.10 | 0.13 | 0.00 | -0.08 | -0.11 | -0.06 | 0.09 | 0.03 | -0.09 | 0.29 | 0.61 | -0.29 | -0.24 | 1.00 | -0.35 | -0.17 | 0.27 | 0.03 |
| apeq_AVE_mean | 0.33 | -0.14 | 0.06 | 0.08 | -0.28 | 0.02 | -0.09 | 0.06 | 0.06 | 0.17 | 0.04 | 0.02 | 0.04 | 0.01 | 0.04 | 0.09 | 0.05 | -0.01 | 0.09 | 0.08 | -0.01 | -0.04 | -0.14 | 0.02 | 0.04 | 0.10 | -0.06 | 0.14 | 0.03 | 0.19 | -0.00 | -0.36 | 0.37 | 0.58 | -0.35 | 1.00 | 0.14 | 0.06 | 0.23 |
| motive_hedonic | 0.05 | -0.07 | 0.07 | 0.03 | -0.26 | -0.10 | -0.07 | 0.03 | 0.02 | 0.09 | 0.02 | 0.22 | 0.29 | 0.23 | 0.23 | 0.28 | 0.13 | 0.17 | 0.31 | -0.20 | -0.20 | 0.03 | 0.07 | 0.27 | 0.11 | -0.22 | -0.02 | 0.06 | -0.08 | 0.12 | -0.15 | -0.22 | 0.08 | 0.13 | -0.17 | 0.14 | 1.00 | -0.01 | 0.00 |
| motive_selfexploration | -0.23 | 0.27 | 0.10 | -0.06 | -0.02 | -0.02 | 0.02 | -0.07 | 0.00 | 0.14 | 0.02 | 0.04 | -0.02 | -0.08 | -0.00 | -0.06 | -0.06 | 0.07 | 0.02 | 0.08 | 0.18 | -0.08 | -0.08 | -0.06 | 0.03 | 0.04 | -0.13 | 0.11 | 0.04 | 0.06 | 0.09 | 0.32 | -0.09 | -0.01 | 0.27 | 0.06 | -0.01 | 1.00 | -0.02 |
| motive_escapist | 0.26 | -0.00 | -0.06 | -0.02 | -0.34 | -0.07 | 0.03 | -0.00 | -0.11 | 0.14 | 0.11 | 0.30 | 0.37 | 0.33 | 0.24 | 0.26 | 0.08 | 0.25 | 0.11 | 0.01 | -0.13 | 0.21 | 0.28 | 0.25 | -0.10 | -0.10 | -0.00 | 0.14 | 0.03 | 0.02 | 0.11 | -0.14 | -0.13 | 0.27 | 0.03 | 0.23 | 0.00 | -0.02 | 1.00 |

## Text lengths (characters, quantiles q00-q95)

| response | n | empty | languages | quantiles |
|---|---|---|---|---|
| acute | 243 | 0 | eng 148, ger 95 | 47 96 144 200 313 398 442 494 548 701 800 917 1106 1314 1679 1936 2179 2662 3368 4489 |
| post | 243 | <10 | eng 148, ger 95 | 5 10 33 61 97 120 142 161 194 217 266 332 413 529 590 716 925 1212 1500 2321 |
| treat | 243 | 10 | eng 148, ger 95 | 5 9 32 68 87 104 121 148 193 234 266 302 329 378 434 528 660 752 912 1260 |

