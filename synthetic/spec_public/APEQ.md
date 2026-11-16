# Public aggregate spec: APEQ

Aggregate statistics only, coarsened for publication by synthetic/public_spec.R (no min/max, no groups < 20 in correlations, no upper 5% of text lengths).

## Sample flow

- raw: 2078
- raw_by_language: eng: 1118, ger: 960
- raw_exclusion_code: 0: 1829, 1: 249
- after_exclusion: 1829
- after_exclusion_by_language: eng: 997, ger: 832
- with_text: 958
- with_text_by_language: eng: 526, ger: 432
- raw_with_text_incl_excluded: 971
- excluded_with_text_by_language: eng: <10, ger: <10
- analysed_WHO: 958
- analysed_AAQ: 958
- analysed_by_language: eng: 526, ger: 432
- WHO_and_AAQ_samples_identical: TRUE
- dropped_zero_variance: none

## Notes on the raw file format

- File `Wolff_APEQ survey data and results.csv`: 306 columns, separator `;`, header in the first row but read with `header = FALSE` (so every column is character and the column names are the literal header strings, e.g. `Age...Jahre`), `comment.char = "#"`.
- Missing values in every column are a single space `' '` (as.numeric(' ') gives NA); the text column uses `' '` for no response.
- Decimal-comma columns: the factor scores are written without a leading zero (`-,0012`, `,53`), with 11-18 decimals, a few in scientific notation (`1,23E-05`); the other `comma_vars` hold integers in this file.
- The generator must not put `#` into the text (comment.char) and must write the file in latin1.
- Rows of excluded participants (Exclusion = 1) can be drawn from the same distributions; they are only counted in the flow.

## Raw columns

| column | role | class_after_read | formats | decimals | conversion | NA_share_raw_file |
|---|---|---|---|---|---|---|
| Exclusion | filter (0 = included) | character | integer: 2078 |  | as.numeric(x) == 0 | 0 |
| Sprache | language (predictor) | character | other: 2078 |  | as.factor | 0 |
| Dose | predictor | character | blank_space: 184; integer: 1894 |  | as.numeric(gsub(',', '.', x)) | 0.089 |
| Strength | predictor | character | blank_space: 184; integer: 1894 |  | as.numeric(gsub(',', '.', x)) | 0.089 |
| Duration | predictor | character | blank_space: 184; integer: 1894 |  | as.numeric(gsub(',', '.', x)) | 0.089 |
| Valence | predictor | character | blank_space: 184; integer: 1894 |  | as.numeric(gsub(',', '.', x)) | 0.089 |
| retrospectiveappraisal | predictor | character | blank_space: 184; integer: 1894 |  | as.numeric(gsub(',', '.', x)) | 0.089 |
| Mood | predictor | character | blank_space: 187; integer: 1891 |  | as.numeric(gsub(',', '.', x)) | 0.090 |
| Preparedness | predictor | character | blank_space: 187; integer: 1891 |  | as.numeric(gsub(',', '.', x)) | 0.090 |
| Factor1_Therapeutic | predictor | character | blank_space: 249; dec_comma: 657; dec_comma_no_leading_zero: 1172 | 11 to 17 decimals | as.numeric(gsub(',', '.', x)) | 0.120 |
| Factor2_Escapist | predictor | character | blank_space: 249; dec_comma: 548; dec_comma_no_leading_zero: 1280; dec_comma_scientific: <10 | 12 to 18 decimals | as.numeric(gsub(',', '.', x)) | 0.120 |
| Factor3_Hedonic | predictor | character | blank_space: 249; dec_comma: 602; dec_comma_no_leading_zero: 1227 | 12 to 18 decimals | as.numeric(gsub(',', '.', x)) | 0.120 |
| EBI_Total | predictor | character | blank_space: 191; integer: 1887 |  | as.numeric(gsub(',', '.', x)) | 0.092 |
| CEQ_Total | predictor | character | blank_space: 191; integer: 1887 |  | as.numeric(gsub(',', '.', x)) | 0.092 |
| WHOdiff | outcome | character | blank_space: 192; integer: 1886 |  | as.numeric(x) | 0.092 |
| AAQdiff | outcome | character | blank_space: 193; integer: 1885 |  | as.numeric(x) | 0.093 |
| Age...Jahre | predictor | character | integer: 2078 |  | as.numeric(x) | 0 |
| APEQ_AVPE | predictor | character | blank_space: 191; integer: 1887 |  | as.numeric(x) | 0.092 |
| APEQ_ACPE | predictor | character | blank_space: 191; integer: 1887 |  | as.numeric(x) | 0.092 |
| Gender | predictor | character | blank_space: 177; integer: 1901 |  | recode 1=Female 2=Male 3=Other -9=NotSpecified | 0.085 |
| PsychedelicUsed | predictor | character | blank_space: 184; integer: 1894 |  | recode 1=LSD 2=Psilocybin 3=Mescaline 4=Ayahuasca | 0.089 |
| Education | predictor (as Education3) | character | blank_space: 177; integer: 1901 |  | CASMIN 1-3=Primary 4-7=Intermediate 8-9=Higher | 0.085 |
| SelectedImpactFreeNennung1 | free text | character | blank_space: 1107; non-blank text: 971 |  | iconv latin1->UTF-8, squish, drop U+FFFD; empty = no text | 0.533 |

## Numeric variables (quantiles q05-q95)

| variable | n | scale | na | quantiles |
|---|---|---|---|---|
| WHOdiff | 958 |  | 0 | -2 0 0 0 0 1 2 2 3 3 4 5 5 6 7 8 9 12 14 |
| AAQdiff | 958 |  | 0 | -26 -20 -17 -15 -13 -11 -9 -8 -7 -6 -5 -4 -3 -2 -1 0 0 0 1 |
| Age...Jahre | 958 |  | 0 | 19 20 21 22 23 24 25 26 27 28 29 30 32 33 35 37 40 45 53 |
| Dose | 958 |  | 0 | 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 4 4 4 4 |
| Strength | 958 |  | 0 | 3 3 3 3 4 4 4 4 4 4 4 4 4 4 5 5 5 5 5 |
| Valence | 958 |  | 0 | 1 1 1 1 1 1 1 1 1 1 2 3 3 3 3 3 3 3 3 |
| Duration | 958 |  | 0 | 2 3 3 3 3 3 3 3 4 4 4 4 4 4 4 4 5 5 5 |
| Mood | 958 |  | 0 | 2 3 3 3 4 4 4 4 4 4 4 4 4 4 4 5 5 5 5 |
| Preparedness | 958 |  | 0 | 2 2 2 3 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 |
| retrospectiveappraisal | 958 |  | 0 | 3 4 4 4 4 4 5 5 5 5 5 5 5 5 5 5 5 5 5 |
| Factor1_Therapeutic | 958 |  | 0 | -1.34 -1.17 -0.99 -0.86 -0.69 -0.58 -0.44 -0.28 -0.13 0.05 0.17 0.31 0.51 0.64 0.79 0.98 1.2 1.42 1.79 |
| Factor2_Escapist | 958 |  | 0 | -1.25 -1.13 -1.01 -0.91 -0.82 -0.73 -0.65 -0.53 -0.43 -0.28 -0.18 -0.05 0.1 0.26 0.5 0.67 0.92 1.25 1.87 |
| Factor3_Hedonic | 958 |  | 0 | -1.58 -1.32 -1.12 -0.93 -0.76 -0.65 -0.48 -0.34 -0.19 -0.05 0.13 0.26 0.42 0.59 0.71 0.92 1.12 1.41 1.8 |
| APEQ_ACPE | 958 |  | 0 | 245 342 440 532 598 650 698 732 765 812 847 886 922 962 989 1026 1071 1110 1160 |
| APEQ_AVPE | 958 |  | 0 | 0 8 19 34 50 68 89 113 132 153 185 223 259 306 349 435 495 632 781 |
| EBI_Total | 958 |  | 0 | 15 54 89 133 175 213 252 295 331 360 387 413 437 463 487 515 543 565 598 |
| CEQ_Total | 958 |  | 0 | 27 29 31 34 35 37 39 41 43 46 49 52 56 61 65 73 83 92 103 |

## Categorical variables

**Gender** (N = 958)

| level | label | n | share |
|---|---|---|---|
| Male |  | 645 | 0.673 |
| Female |  | 298 | 0.311 |
| Other |  | 15 | 0.016 |

**PsychedelicUsed** (N = 958)

| level | label | n | share |
|---|---|---|---|
| LSD |  | 459 | 0.479 |
| Psilocybin |  | 396 | 0.413 |
| Ayahuasca |  | 93 | 0.097 |
| Mescaline |  | 10 | 0.010 |

**Education3** (N = 958)

| level | label | n | share |
|---|---|---|---|
| Higher |  | 514 | 0.537 |
| Intermediate |  | 427 | 0.446 |
| Primary |  | 17 | 0.018 |

**Sprache** (N = 958)

| level | label | n | share |
|---|---|---|---|
| eng |  | 526 | 0.549 |
| ger |  | 432 | 0.451 |

**Education_raw** (N = 958)

| level | label | n | share |
|---|---|---|---|
| 8 | raw CASMIN code | 306 | 0.319 |
| 6 | raw CASMIN code | 251 | 0.262 |
| 9 | raw CASMIN code | 208 | 0.217 |
| 7 | raw CASMIN code | 134 | 0.140 |
| 5 | raw CASMIN code | 25 | 0.026 |
| 4 | raw CASMIN code | 17 | 0.018 |
| other | 2 level(s) with <10 each, pooled | 17 | 0.018 |

## Correlation matrix (normal scores)

Analysed sample (identical for WHO and AAQ)

Left out: Gender=Other, PsychedelicUsed=Mescaline, Education3=Primary

| variable | WHOdiff | AAQdiff | Age...Jahre | Gender=Female | PsychedelicUsed=Psilocybin | PsychedelicUsed=Ayahuasca | Education3=Intermediate | Sprache=ger | Dose | Strength | Valence | Duration | Mood | Preparedness | retrospectiveappraisal | Factor1_Therapeutic | Factor2_Escapist | Factor3_Hedonic | APEQ_ACPE | APEQ_AVPE | EBI_Total | CEQ_Total |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| WHOdiff | 1.00 | -0.68 | 0.07 | 0.03 | 0.10 | 0.07 | -0.01 | -0.27 | 0.02 | 0.04 | -0.06 | -0.07 | -0.22 | -0.03 | 0.35 | 0.42 | -0.04 | -0.07 | 0.46 | -0.13 | 0.39 | -0.11 |
| AAQdiff | -0.68 | 1.00 | -0.01 | -0.05 | -0.07 | -0.08 | -0.03 | 0.23 | -0.06 | -0.11 | 0.00 | 0.03 | 0.18 | 0.03 | -0.35 | -0.40 | 0.12 | 0.03 | -0.54 | 0.08 | -0.51 | 0.03 |
| Age...Jahre | 0.07 | -0.01 | 1.00 | 0.05 | 0.06 | 0.19 | -0.30 | -0.12 | 0.04 | 0.03 | -0.04 | -0.14 | -0.08 | 0.02 | 0.10 | 0.14 | -0.14 | -0.18 | 0.01 | -0.14 | 0.01 | -0.12 |
| Gender=Female | 0.03 | -0.05 | 0.05 | 1.00 | -0.02 | 0.03 | -0.09 | 0.06 | -0.13 | -0.04 | -0.02 | -0.03 | -0.04 | 0.01 | -0.05 | 0.01 | -0.02 | 0.02 | 0.00 | -0.03 | 0.03 | -0.04 |
| PsychedelicUsed=Psilocybin | 0.10 | -0.07 | 0.06 | -0.02 | 1.00 | -0.28 | 0.04 | -0.16 | -0.00 | -0.03 | -0.03 | -0.41 | -0.11 | 0.02 | 0.05 | 0.12 | -0.06 | 0.01 | 0.08 | -0.07 | 0.07 | -0.06 |
| PsychedelicUsed=Ayahuasca | 0.07 | -0.08 | 0.19 | 0.03 | -0.28 | 1.00 | -0.10 | -0.03 | 0.10 | 0.11 | 0.13 | -0.16 | -0.07 | -0.03 | 0.06 | 0.19 | -0.26 | -0.16 | 0.10 | 0.08 | 0.14 | 0.12 |
| Education3=Intermediate | -0.01 | -0.03 | -0.30 | -0.09 | 0.04 | -0.10 | 1.00 | 0.07 | 0.02 | -0.00 | 0.01 | 0.03 | 0.03 | 0.03 | -0.05 | 0.00 | 0.07 | 0.05 | 0.02 | -0.01 | 0.01 | 0.01 |
| Sprache=ger | -0.27 | 0.23 | -0.12 | 0.06 | -0.16 | -0.03 | 0.07 | 1.00 | -0.04 | -0.03 | -0.02 | 0.08 | 0.13 | 0.14 | -0.10 | -0.36 | -0.03 | 0.00 | -0.19 | -0.11 | -0.23 | 0.01 |
| Dose | 0.02 | -0.06 | 0.04 | -0.13 | -0.00 | 0.10 | 0.02 | -0.04 | 1.00 | 0.53 | 0.16 | 0.11 | -0.00 | -0.07 | 0.08 | 0.05 | -0.01 | 0.03 | 0.17 | 0.12 | 0.17 | 0.24 |
| Strength | 0.04 | -0.11 | 0.03 | -0.04 | -0.03 | 0.11 | -0.00 | -0.03 | 0.53 | 1.00 | 0.15 | 0.12 | -0.01 | -0.13 | 0.10 | 0.05 | -0.05 | -0.03 | 0.17 | 0.15 | 0.15 | 0.26 |
| Valence | -0.06 | 0.00 | -0.04 | -0.02 | -0.03 | 0.13 | 0.01 | -0.02 | 0.16 | 0.15 | 1.00 | 0.03 | -0.14 | -0.19 | -0.21 | 0.11 | -0.04 | -0.15 | 0.06 | 0.45 | 0.14 | 0.47 |
| Duration | -0.07 | 0.03 | -0.14 | -0.03 | -0.41 | -0.16 | 0.03 | 0.08 | 0.11 | 0.12 | 0.03 | 1.00 | 0.07 | -0.01 | -0.04 | -0.13 | 0.10 | 0.03 | -0.02 | 0.03 | -0.03 | 0.09 |
| Mood | -0.22 | 0.18 | -0.08 | -0.04 | -0.11 | -0.07 | 0.03 | 0.13 | -0.00 | -0.01 | -0.14 | 0.07 | 1.00 | 0.27 | 0.09 | -0.33 | -0.09 | 0.24 | -0.15 | -0.18 | -0.19 | -0.19 |
| Preparedness | -0.03 | 0.03 | 0.02 | 0.01 | 0.02 | -0.03 | 0.03 | 0.14 | -0.07 | -0.13 | -0.19 | -0.01 | 0.27 | 1.00 | 0.14 | 0.06 | -0.23 | 0.18 | 0.03 | -0.29 | -0.03 | -0.26 |
| retrospectiveappraisal | 0.35 | -0.35 | 0.10 | -0.05 | 0.05 | 0.06 | -0.05 | -0.10 | 0.08 | 0.10 | -0.21 | -0.04 | 0.09 | 0.14 | 1.00 | 0.08 | -0.22 | 0.09 | 0.38 | -0.40 | 0.23 | -0.31 |
| Factor1_Therapeutic | 0.42 | -0.40 | 0.14 | 0.01 | 0.12 | 0.19 | 0.00 | -0.36 | 0.05 | 0.05 | 0.11 | -0.13 | -0.33 | 0.06 | 0.08 | 1.00 | -0.05 | -0.02 | 0.43 | 0.15 | 0.46 | 0.14 |
| Factor2_Escapist | -0.04 | 0.12 | -0.14 | -0.02 | -0.06 | -0.26 | 0.07 | -0.03 | -0.01 | -0.05 | -0.04 | 0.10 | -0.09 | -0.23 | -0.22 | -0.05 | 1.00 | 0.03 | -0.20 | 0.21 | -0.16 | 0.02 |
| Factor3_Hedonic | -0.07 | 0.03 | -0.18 | 0.02 | 0.01 | -0.16 | 0.05 | 0.00 | 0.03 | -0.03 | -0.15 | 0.03 | 0.24 | 0.18 | 0.09 | -0.02 | 0.03 | 1.00 | 0.12 | -0.03 | 0.04 | -0.10 |
| APEQ_ACPE | 0.46 | -0.54 | 0.01 | 0.00 | 0.08 | 0.10 | 0.02 | -0.19 | 0.17 | 0.17 | 0.06 | -0.02 | -0.15 | 0.03 | 0.38 | 0.43 | -0.20 | 0.12 | 1.00 | -0.03 | 0.79 | 0.05 |
| APEQ_AVPE | -0.13 | 0.08 | -0.14 | -0.03 | -0.07 | 0.08 | -0.01 | -0.11 | 0.12 | 0.15 | 0.45 | 0.03 | -0.18 | -0.29 | -0.40 | 0.15 | 0.21 | -0.03 | -0.03 | 1.00 | 0.11 | 0.69 |
| EBI_Total | 0.39 | -0.51 | 0.01 | 0.03 | 0.07 | 0.14 | 0.01 | -0.23 | 0.17 | 0.15 | 0.14 | -0.03 | -0.19 | -0.03 | 0.23 | 0.46 | -0.16 | 0.04 | 0.79 | 0.11 | 1.00 | 0.19 |
| CEQ_Total | -0.11 | 0.03 | -0.12 | -0.04 | -0.06 | 0.12 | 0.01 | 0.01 | 0.24 | 0.26 | 0.47 | 0.09 | -0.19 | -0.26 | -0.31 | 0.14 | 0.02 | -0.10 | 0.05 | 0.69 | 0.19 | 1.00 |

## Text lengths (characters, quantiles q00-q95)

| response | n | empty | languages | quantiles |
|---|---|---|---|---|
| text | 958 | 0 | eng 526, ger 432 | 10 26 37 46 55 64 73 84 94 102 114 126 137 151 173 199 229 270 331 489 |

